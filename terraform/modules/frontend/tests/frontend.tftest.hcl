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

run "enabled_frontend" {
  command = apply

  variables {
    enable_frontend_modules = true
    bucket_name             = "47log-test-frontend"
  }

  assert {
    condition = (
      aws_s3_bucket_public_access_block.this[0].block_public_acls &&
      aws_s3_bucket_public_access_block.this[0].block_public_policy &&
      aws_s3_bucket_public_access_block.this[0].ignore_public_acls &&
      aws_s3_bucket_public_access_block.this[0].restrict_public_buckets
    )
    error_message = "S3の公開アクセスをすべてブロックする必要があります。"
  }

  assert {
    condition = (
      jsondecode(aws_s3_bucket_policy.this[0].policy).Statement[0].Principal.Service == "cloudfront.amazonaws.com" &&
      jsondecode(aws_s3_bucket_policy.this[0].policy).Statement[0].Action == "s3:GetObject" &&
      jsondecode(aws_s3_bucket_policy.this[0].policy).Statement[0].Resource == "${aws_s3_bucket.this[0].arn}/*" &&
      jsondecode(aws_s3_bucket_policy.this[0].policy).Statement[0].Condition.StringEquals["AWS:SourceArn"] == aws_cloudfront_distribution.this[0].arn
    )
    error_message = "CloudFrontの読み取り権限は対象Distributionとバケットのオブジェクトに限定する必要があります。"
  }

  assert {
    condition = (
      aws_cloudfront_origin_access_control.this[0].signing_behavior == "always" &&
      aws_cloudfront_distribution.this[0].default_cache_behavior[0].viewer_protocol_policy == "redirect-to-https" &&
      anytrue([
        for association in aws_cloudfront_distribution.this[0].default_cache_behavior[0].function_association :
        association.event_type == "viewer-request" && association.function_arn == aws_cloudfront_function.spa_router[0].arn
      ])
    )
    error_message = "OAC署名、HTTPSへのリダイレクト、SPAルーティングが必要です。"
  }

  assert {
    condition = (
      output.s3_bucket_name == "47log-test-frontend" &&
      output.s3_bucket_arn == aws_s3_bucket.this[0].arn &&
      output.frontend_url == "https://${output.cloudfront_domain_name}"
    )
    error_message = "outputsは作成したリソースの値を返す必要があります。"
  }
}

run "disabled_frontend" {
  command = apply

  variables {
    enable_frontend_modules = false
  }

  assert {
    condition = (
      length(aws_s3_bucket.this) == 0 &&
      length(aws_s3_bucket_public_access_block.this) == 0 &&
      length(aws_s3_bucket_ownership_controls.this) == 0 &&
      length(aws_s3_bucket_server_side_encryption_configuration.this) == 0 &&
      length(aws_s3_bucket_policy.this) == 0 &&
      length(aws_cloudfront_origin_access_control.this) == 0 &&
      length(aws_cloudfront_cache_policy.this) == 0 &&
      length(aws_cloudfront_function.spa_router) == 0 &&
      length(aws_cloudfront_distribution.this) == 0 &&
      length(data.aws_cloudfront_response_headers_policy.security) == 0
    )
    error_message = "無効時はリソースとデータソースを作成しない必要があります。"
  }

  assert {
    condition = (
      output.s3_bucket_name == null &&
      output.s3_bucket_arn == null &&
      output.cloudfront_distribution_id == null &&
      output.cloudfront_domain_name == null &&
      output.frontend_url == null
    )
    error_message = "無効時のoutputsはnullである必要があります。"
  }
}

run "enabled_without_bucket_name" {
  command = plan

  variables {
    enable_frontend_modules = true
  }

  expect_failures = [var.bucket_name]
}

run "enabled_with_blank_bucket_name" {
  command = plan

  variables {
    enable_frontend_modules = true
    bucket_name             = " "
  }

  expect_failures = [var.bucket_name]
}
