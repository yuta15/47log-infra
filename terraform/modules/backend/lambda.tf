resource "aws_lambda_function" "this" {
  for_each = local.lambdas

  function_name = "${var.name}-${each.key}"
  package_type  = "Image"
  image_uri     = each.value.image_uri
  role          = aws_iam_role.this[each.key].arn
  architectures = [each.value.architecture]
  memory_size   = each.value.memory_size
  timeout       = each.value.timeout
  tags          = var.tags

  lifecycle {
    # 初回作成のみTerraformで指定し、以降のイメージ更新はアプリのCI/CDが管理する。
    ignore_changes = [image_uri]
  }

  dynamic "environment" {
    for_each = length(each.value.environment_variables) > 0 ? [each.value.environment_variables] : []

    content {
      variables = environment.value
    }
  }

  depends_on = [
    aws_iam_role_policy.logs,
    aws_iam_role_policy.dynamodb,
  ]
}

resource "aws_cloudwatch_log_group" "this" {
  for_each = local.lambdas

  name              = "/aws/lambda/${var.name}-${each.key}"
  retention_in_days = 30
  tags              = var.tags
}
