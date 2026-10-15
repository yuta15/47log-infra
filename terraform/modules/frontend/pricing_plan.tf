resource "aws_cloudformation_stack" "free_plan" {
  region = "us-east-1"
  name   = "cloudfront-free-${var.project_name}"
  tags   = var.tags

  # ARNの参照により、加入はDistribution作成後、解除はDistribution削除前に行う。
  parameters = {
    DistributionArn = aws_cloudfront_distribution.this.arn
    WebAclArn       = aws_wafv2_web_acl.this.arn
  }

  template_body = jsonencode({
    AWSTemplateFormatVersion = "2010-09-09"
    Description              = "Manage the frontend CloudFront Free plan subscription through CloudFormation."
    Metadata = {
      AWSToolsMetrics = {
        AWSAgentToolkit = "aws-cloudformation@3"
      }
    }
    Parameters = {
      DistributionArn = { Type = "String" }
      WebAclArn       = { Type = "String" }
    }
    Resources = {
      Subscription = {
        Type = "AWS::PricingPlanManager::Subscription"
        Metadata = {
          "com.aws.cloudformation.Context" = {
            why  = "Keep pricing enrollment in Terraform state without a dedicated provider resource."
            must = ["Enroll only after the distribution has its dedicated CloudFront-scope web ACL.", "Cancel before deleting the distribution or web ACL."]
          }
        }
        Properties = {
          PlanFamily = "CloudFront"
          PlanTier   = "FREE"
          UsageLevel = "DEFAULT"
          ResourceArns = [
            { Ref = "DistributionArn" },
            { Ref = "WebAclArn" },
          ]
        }
      }
    }
  })
}
