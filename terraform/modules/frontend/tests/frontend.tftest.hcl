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

  mock_resource "aws_wafv2_web_acl" {
    defaults = {
      arn = "arn:aws:wafv2:us-east-1:123456789012:global/webacl/47log-test-frontend-waf/00000000-0000-0000-0000-000000000000"
    }
  }

  mock_resource "aws_wafv2_ip_set" {
    defaults = {
      arn = "arn:aws:wafv2:us-east-1:123456789012:global/ipset/47log-test-frontend-dev-ipv4/00000000-0000-0000-0000-000000000001"
    }
  }
}

variables {
  project_name = "47log-test-frontend"
}

run "frontend_resources" {
  command = apply

  assert {
    condition = (
      aws_s3_bucket.this.bucket == var.project_name &&
      aws_cloudfront_origin_access_control.this.name == "${var.project_name}-oac" &&
      aws_cloudfront_function.spa_router.name == "spa-${substr(var.project_name, 0, 48)}-${substr(sha1(var.project_name), 0, 8)}"
    )
    error_message = "S3とCloudFrontの名前は共通のproject_nameから生成する必要があります。"
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
      data.aws_cloudfront_cache_policy.this.name == "Managed-CachingOptimized" &&
      aws_cloudfront_distribution.this.default_cache_behavior[0].cache_policy_id == data.aws_cloudfront_cache_policy.this.id &&
      aws_cloudfront_distribution.this.default_cache_behavior[0].viewer_protocol_policy == "redirect-to-https" &&
      anytrue([
        for association in aws_cloudfront_distribution.this.default_cache_behavior[0].function_association :
        association.event_type == "viewer-request" && association.function_arn == aws_cloudfront_function.spa_router.arn
      ])
    )
    error_message = "OAC署名、管理キャッシュポリシー、HTTPSへのリダイレクト、SPAルーティングが必要です。"
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

run "free_pricing_plan" {
  command = apply

  assert {
    condition = (
      aws_wafv2_web_acl.this.region == "us-east-1" &&
      aws_wafv2_web_acl.this.scope == "CLOUDFRONT" &&
      aws_cloudfront_distribution.this.web_acl_id == aws_wafv2_web_acl.this.arn &&
      aws_wafv2_web_acl.this.tags == var.tags
    )
    error_message = "専用のCloudFrontスコープのWAFをus-east-1に作成し、ARNでDistributionに関連付ける必要があります。"
  }

  assert {
    condition = (
      length([for rule in aws_wafv2_web_acl.this.rule : rule if rule.name == "ip-rate-limit"]) == 1 &&
      alltrue([
        for rule in aws_wafv2_web_acl.this.rule : (
          length(rule.action[0].block) == 1 &&
          rule.priority == 1 &&
          rule.statement[0].rate_based_statement[0].aggregate_key_type == "IP" &&
          rule.statement[0].rate_based_statement[0].evaluation_window_sec == 300 &&
          rule.statement[0].rate_based_statement[0].limit == 2000
        ) if rule.name == "ip-rate-limit"
      ])
    )
    error_message = "WAFはIPごとに5分間2000リクエストを基準としてブロックする必要があります。"
  }

  assert {
    condition = (
      length(aws_wafv2_web_acl.this.rule) == 2 &&
      length(aws_wafv2_web_acl.this.default_action[0].allow) == 1 &&
      length([for rule in aws_wafv2_web_acl.this.rule : rule if rule.name == "block-outside-japan"]) == 1 &&
      alltrue([
        for rule in aws_wafv2_web_acl.this.rule : (
          rule.priority == 0 &&
          length(rule.action[0].block) == 1 &&
          length(rule.statement[0].not_statement[0].statement[0].geo_match_statement[0].country_codes) == 1 &&
          contains(rule.statement[0].not_statement[0].statement[0].geo_match_statement[0].country_codes, "JP") &&
          length(rule.statement[0].not_statement[0].statement[0].geo_match_statement[0].forwarded_ip_config) == 0
        ) if rule.name == "block-outside-japan"
      ])
    )
    error_message = "送信元IPの国判定が日本以外のアクセスを先にブロックし、日本からのアクセスにもレート制限を適用する必要があります。"
  }

  assert {
    condition = (
      aws_cloudformation_stack.free_plan.region == "us-east-1" &&
      aws_cloudformation_stack.free_plan.parameters.DistributionArn == aws_cloudfront_distribution.this.arn &&
      aws_cloudformation_stack.free_plan.parameters.WebAclArn == aws_wafv2_web_acl.this.arn &&
      jsondecode(aws_cloudformation_stack.free_plan.template_body).Resources.Subscription.Type == "AWS::PricingPlanManager::Subscription" &&
      jsondecode(aws_cloudformation_stack.free_plan.template_body).Resources.Subscription.Properties.PlanFamily == "CloudFront" &&
      jsondecode(aws_cloudformation_stack.free_plan.template_body).Resources.Subscription.Properties.PlanTier == "FREE" &&
      jsondecode(aws_cloudformation_stack.free_plan.template_body).Resources.Subscription.Properties.UsageLevel == "DEFAULT" &&
      jsondecode(aws_cloudformation_stack.free_plan.template_body).Resources.Subscription.Properties.ResourceArns == [
        { Ref = "DistributionArn" },
        { Ref = "WebAclArn" },
      ]
    )
    error_message = "作成したDistributionとWAFのみをCloudFormation経由でFree planに加入させる必要があります。"
  }
}

run "development_ip_allowlist" {
  command = apply

  override_resource {
    target = aws_wafv2_ip_set.development["ipv6"]
    values = {
      arn = "arn:aws:wafv2:us-east-1:123456789012:global/ipset/47log-test-frontend-dev-ipv6/00000000-0000-0000-0000-000000000002"
    }
  }

  variables {
    tags                         = { Environment = "development" }
    development_allowed_ip_cidrs = ["203.0.113.10/32", "2001:db8::10/128"]
  }

  assert {
    condition = (
      length(aws_wafv2_web_acl.this.default_action[0].block) == 1 &&
      length(aws_wafv2_web_acl.this.default_action[0].allow) == 0 &&
      length(aws_wafv2_web_acl.this.rule) == 3 &&
      length(aws_wafv2_ip_set.development) == 2 &&
      aws_wafv2_ip_set.development["ipv4"].ip_address_version == "IPV4" &&
      aws_wafv2_ip_set.development["ipv6"].ip_address_version == "IPV6" &&
      toset(aws_wafv2_ip_set.development["ipv4"].addresses) == toset(["203.0.113.10/32"]) &&
      toset(aws_wafv2_ip_set.development["ipv6"].addresses) == toset(["2001:db8::10/128"])
    )
    error_message = "devだけを既定拒否にし、IPv4とIPv6の許可IPを別々のIP Setに登録する必要があります。"
  }

  assert {
    condition = (
      length([for rule in aws_wafv2_web_acl.this.rule : rule if rule.name == "allow-development-ips"]) == 1 &&
      alltrue([
        for rule in aws_wafv2_web_acl.this.rule : (
          rule.priority == 2 &&
          length(rule.action[0].allow) == 1 &&
          toset([for statement in rule.statement[0].or_statement[0].statement : statement.ip_set_reference_statement[0].arn]) ==
          toset([for ip_set in aws_wafv2_ip_set.development : ip_set.arn])
        ) if rule.name == "allow-development-ips"
      ]) &&
      toset([for rule in aws_wafv2_web_acl.this.rule : rule.priority if contains(["block-outside-japan", "ip-rate-limit"], rule.name)]) == toset([0, 1])
    )
    error_message = "日本限定とレート制限の評価後に、登録したIPだけを許可する必要があります。"
  }
}

run "dev_without_allowed_ip" {
  command = apply

  override_resource {
    target = aws_wafv2_ip_set.development["ipv6"]
    values = {
      arn = "arn:aws:wafv2:us-east-1:123456789012:global/ipset/47log-test-frontend-dev-ipv6/00000000-0000-0000-0000-000000000002"
    }
  }

  variables {
    tags = { Environment = "dev" }
  }

  assert {
    condition = (
      length(aws_wafv2_web_acl.this.default_action[0].block) == 1 &&
      length(aws_wafv2_web_acl.this.default_action[0].allow) == 0 &&
      length(aws_wafv2_web_acl.this.rule) == 3 &&
      alltrue([for ip_set in aws_wafv2_ip_set.development : length(ip_set.addresses) == 0])
    )
    error_message = "devで許可IPが未指定の場合は全アクセスを拒否する必要があります。"
  }
}

run "production_without_allowed_ip" {
  command = apply

  variables {
    tags = { Environment = "production" }
  }

  assert {
    condition = (
      length(aws_wafv2_web_acl.this.default_action[0].allow) == 1 &&
      length(aws_wafv2_web_acl.this.default_action[0].block) == 0 &&
      length(aws_wafv2_web_acl.this.rule) == 2 &&
      length(aws_wafv2_ip_set.development) == 0
    )
    error_message = "productionではIP未指定でも既定許可を維持し、IP制限を作成しない必要があります。"
  }
}

run "production_ignores_allowed_ip" {
  command = apply

  variables {
    tags                         = { Environment = "production" }
    development_allowed_ip_cidrs = ["203.0.113.10/32"]
  }

  assert {
    condition = (
      length(aws_wafv2_web_acl.this.default_action[0].allow) == 1 &&
      length(aws_wafv2_web_acl.this.rule) == 2 &&
      length(aws_wafv2_ip_set.development) == 0
    )
    error_message = "productionでは許可IPの入力にかかわらずIP制限を有効にしない必要があります。"
  }
}

run "invalid_allowed_ip" {
  command = plan

  variables {
    development_allowed_ip_cidrs = ["not-an-ip/32"]
  }

  expect_failures = [var.development_allowed_ip_cidrs]
}

run "allowed_network_rejected" {
  command = plan

  variables {
    development_allowed_ip_cidrs = ["203.0.113.0/24"]
  }

  expect_failures = [var.development_allowed_ip_cidrs]
}

run "min_project_name_length" {
  command = plan

  variables {
    project_name = "a-1"
  }

  assert {
    condition = (
      aws_s3_bucket.this.bucket == var.project_name &&
      length(aws_cloudfront_origin_access_control.this.name) <= 64 &&
      can(regex("^[a-zA-Z0-9_-]{1,64}$", aws_cloudfront_function.spa_router.name))
    )
    error_message = "許可したproject_nameでS3とCloudFrontの命名制約を満たす必要があります。"
  }
}

run "max_project_name_length" {
  command = plan

  variables {
    project_name = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  }

  assert {
    condition = (
      aws_s3_bucket.this.bucket == var.project_name &&
      length(aws_cloudfront_origin_access_control.this.name) <= 64 &&
      can(regex("^[a-zA-Z0-9_-]{1,64}$", aws_cloudfront_function.spa_router.name))
    )
    error_message = "許可したproject_nameでS3とCloudFrontの命名制約を満たす必要があります。"
  }
}

run "null_project_name" {
  command = plan

  variables {
    project_name = null
  }

  expect_failures = [var.project_name]
}

run "blank_project_name" {
  command = plan

  variables {
    project_name = " "
  }

  expect_failures = [var.project_name]
}

run "short_project_name" {
  command = plan

  variables {
    project_name = "ab"
  }

  expect_failures = [var.project_name]
}

run "long_project_name" {
  command = plan

  variables {
    project_name = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  }

  expect_failures = [var.project_name]
}

run "dotted_project_name" {
  command = plan

  variables {
    project_name = "app.example.com"
  }

  expect_failures = [var.project_name]
}

run "uppercase_project_name" {
  command = plan

  variables {
    project_name = "App-example"
  }

  expect_failures = [var.project_name]
}

run "underscore_project_name" {
  command = plan

  variables {
    project_name = "app_example"
  }

  expect_failures = [var.project_name]
}

run "leading_hyphen" {
  command = plan

  variables {
    project_name = "-app"
  }

  expect_failures = [var.project_name]
}

run "trailing_hyphen" {
  command = plan

  variables {
    project_name = "app-"
  }

  expect_failures = [var.project_name]
}

run "reserved_prefix_0" {
  command = plan

  variables {
    project_name = "xn--app"
  }

  expect_failures = [var.project_name]
}

run "reserved_prefix_1" {
  command = plan

  variables {
    project_name = "sthree-app"
  }

  expect_failures = [var.project_name]
}

run "reserved_prefix_2" {
  command = plan

  variables {
    project_name = "amzn-s3-demo-app"
  }

  expect_failures = [var.project_name]
}

run "reserved_suffix_0" {
  command = plan

  variables {
    project_name = "app-s3alias"
  }

  expect_failures = [var.project_name]
}

run "reserved_suffix_1" {
  command = plan

  variables {
    project_name = "app--ol-s3"
  }

  expect_failures = [var.project_name]
}

run "reserved_suffix_2" {
  command = plan

  variables {
    project_name = "app--x-s3"
  }

  expect_failures = [var.project_name]
}

run "reserved_suffix_3" {
  command = plan

  variables {
    project_name = "app--table-s3"
  }

  expect_failures = [var.project_name]
}

run "reserved_suffix_4" {
  command = plan

  variables {
    project_name = "app-an"
  }

  expect_failures = [var.project_name]
}
