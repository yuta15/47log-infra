resource "aws_iam_role" "this" {
  for_each = local.lambdas

  # IAMロール名の上限64文字に収まる一意な名前を生成する。
  name_prefix = "${substr(each.key, 0, 26)}-lambda-"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy" "logs" {
  for_each = local.lambdas

  name = "cloudwatch-logs"
  role = aws_iam_role.this[each.key].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Resource = "${aws_cloudwatch_log_group.this[each.key].arn}:*"
    }]
  })
}

resource "aws_iam_role_policy" "dynamodb" {
  for_each = { for key, route in local.lambdas : key => route if length(route.table_arns) > 0 }

  name = "dynamodb-access"
  role = aws_iam_role.this[each.key].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "TableReadWrite"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:BatchGetItem",
          "dynamodb:BatchWriteItem",
          "dynamodb:DescribeTable",
          "dynamodb:ConditionCheckItem",
        ]
        Resource = values(each.value.table_arns)
      },
      {
        Sid      = "TableAndIndexQuery"
        Effect   = "Allow"
        Action   = ["dynamodb:Query", "dynamodb:Scan"]
        Resource = concat(values(each.value.table_arns), [for arn in values(each.value.table_arns) : "${arn}/index/*"])
      },
    ]
  })
}
