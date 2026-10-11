tflint {
  required_version = ">= 0.64.0"
}

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "aws" {
  enabled = true
  version = "0.48.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

# main.tfへの集約を強制せず、s3.tf・cloudfront.tfで責務を分ける。
rule "terraform_standard_module_structure" {
  enabled = false
}
