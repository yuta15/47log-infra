locals {
  is_development = contains(["dev", "development"], lookup(var.tags, "Environment", ""))
  development_ip_sets = local.is_development ? {
    ipv4 = {
      version   = "IPV4"
      addresses = [for cidr in var.development_allowed_ip_cidrs : cidr if !strcontains(cidr, ":")]
    }
    ipv6 = {
      version   = "IPV6"
      addresses = [for cidr in var.development_allowed_ip_cidrs : cidr if strcontains(cidr, ":")]
    }
  } : {}
}

resource "aws_wafv2_ip_set" "development" {
  for_each = local.development_ip_sets

  region             = "us-east-1"
  name               = "${var.project_name}-dev-${each.key}"
  scope              = "CLOUDFRONT"
  ip_address_version = each.value.version
  addresses          = each.value.addresses
  tags               = var.tags
}

resource "aws_wafv2_web_acl" "this" {
  region = "us-east-1"
  name   = "${var.project_name}-waf"
  scope  = "CLOUDFRONT"
  tags   = var.tags

  default_action {
    dynamic "allow" {
      for_each = local.is_development ? [] : [true]
      content {}
    }

    dynamic "block" {
      for_each = local.is_development ? [true] : []
      content {}
    }
  }

  rule {
    name     = "block-outside-japan"
    priority = 0

    action {
      block {}
    }

    statement {
      not_statement {
        statement {
          geo_match_statement {
            country_codes = ["JP"]
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-block-outside-japan"
      sampled_requests_enabled   = false
    }
  }

  rule {
    name     = "ip-rate-limit"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        aggregate_key_type    = "IP"
        evaluation_window_sec = 300
        limit                 = 2000
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-ip-rate-limit"
      sampled_requests_enabled   = false
    }
  }

  dynamic "rule" {
    for_each = local.is_development ? [true] : []

    content {
      name     = "allow-development-ips"
      priority = 2

      action {
        allow {}
      }

      statement {
        or_statement {
          statement {
            ip_set_reference_statement {
              arn = aws_wafv2_ip_set.development["ipv4"].arn
            }
          }

          statement {
            ip_set_reference_statement {
              arn = aws_wafv2_ip_set.development["ipv6"].arn
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.project_name}-allow-development-ips"
        sampled_requests_enabled   = false
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-waf"
    sampled_requests_enabled   = false
  }
}
