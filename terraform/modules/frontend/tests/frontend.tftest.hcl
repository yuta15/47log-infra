mock_provider "aws" {
  mock_resource "aws_s3_bucket" {
    defaults = {
      arn                         = "arn:aws:s3:::47log-test-frontend"
      bucket_regional_domain_name = "47log-test-frontend.s3.ap-northeast-1.amazonaws.com"
    }
  }

  mock_resource "aws_cloudfront_distribution" {
    defaults = {
      arn         = "arn:aws:cloudfront::123456789012:distribution/ETESTFRONTEND"
      domain_name = "test.cloudfront.net"
    }
  }

  mock_resource "aws_cloudfront_function" {
    defaults = {
      arn = "arn:aws:cloudfront::123456789012:function/spa-test-frontend"
    }
  }
}

run "frontend_resources" {
  command = apply

  variables {

    bucket_name = "47log-test-frontend"
  }

  assert {
    condition = (
      aws_s3_bucket_public_access_block.this.block_public_acls &&
      aws_s3_bucket_public_access_block.this.block_public_policy &&
      aws_s3_bucket_public_access_block.this.ignore_public_acls &&
      aws_s3_bucket_public_access_block.this.restrict_public_buckets
    )
    error_message = "S3の公開アクセスをすべてブロックする必要があります。"
  }

  assert {
    condition = (
      jsondecode(aws_s3_bucket_policy.this.policy).Statement[0].Principal.Service == "cloudfront.amazonaws.com" &&
      jsondecode(aws_s3_bucket_policy.this.policy).Statement[0].Action == "s3:GetObject" &&
      jsondecode(aws_s3_bucket_policy.this.policy).Statement[0].Resource == "${aws_s3_bucket.this.arn}/*" &&
      jsondecode(aws_s3_bucket_policy.this.policy).Statement[0].Condition.StringEquals["AWS:SourceArn"] == aws_cloudfront_distribution.this.arn
    )
    error_message = "CloudFrontの読み取り権限は対象Distributionとバケットのオブジェクトに限定する必要があります。"
  }

  assert {
    condition = (
      aws_cloudfront_origin_access_control.this.signing_behavior == "always" &&
      aws_cloudfront_distribution.this.default_cache_behavior[0].viewer_protocol_policy == "redirect-to-https" &&
      anytrue([
        for association in aws_cloudfront_distribution.this.default_cache_behavior[0].function_association :
        association.event_type == "viewer-request" && association.function_arn == aws_cloudfront_function.spa_router.arn
      ])
    )
    error_message = "OAC署名、HTTPSへのリダイレクト、SPAルーティングが必要です。"
  }

  assert {
    condition = (
      output.s3_bucket_name == "47log-test-frontend" &&
      output.s3_bucket_arn == aws_s3_bucket.this.arn &&
      output.frontend_url == "https://${output.cloudfront_domain_name}"
    )
    error_message = "outputsは作成したリソースの値を返す必要があります。"
  }
}

run "singleton_outputs" {
  command = apply
  variables { bucket_name = "47log-test-frontend" }
  assert {
    condition = (
      aws_s3_bucket_ownership_controls.this.rule[0].object_ownership == "BucketOwnerEnforced" &&
      one(aws_s3_bucket_server_side_encryption_configuration.this.rule).apply_server_side_encryption_by_default[0].sse_algorithm == "AES256" &&
      aws_cloudfront_distribution.this.default_cache_behavior[0].response_headers_policy_id == data.aws_cloudfront_response_headers_policy.security.id &&
      output.s3_bucket_name == aws_s3_bucket.this.bucket &&
      output.s3_bucket_arn == aws_s3_bucket.this.arn &&
      output.cloudfront_distribution_id == aws_cloudfront_distribution.this.id &&
      output.cloudfront_domain_name == aws_cloudfront_distribution.this.domain_name &&
      output.frontend_url == "https://${aws_cloudfront_distribution.this.domain_name}"
    )
    error_message = "単一リソースの設定を維持し、outputsは各リソースの値を直接返す必要があります。"
  }
}

run "null_bucket_name" {
  command = plan

  variables {
    bucket_name = null
  }

  expect_failures = [var.bucket_name]
}

run "blank_bucket_name" {
  command = plan

  variables {

    bucket_name = " "
  }

  expect_failures = [var.bucket_name]
}
