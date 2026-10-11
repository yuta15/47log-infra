output "api_id" {
  description = "HTTP APIのID。"
  value       = aws_apigatewayv2_api.this.id
}

output "api_endpoint" {
  description = "$defaultステージのHTTP APIエンドポイント。"
  value       = aws_apigatewayv2_api.this.api_endpoint
}

output "lambda_function_names" {
  description = "Lambda識別子をキーとするLambda関数名。"
  value       = { for key, function in aws_lambda_function.this : key => function.function_name }
}

output "lambda_function_arns" {
  description = "Lambda識別子をキーとするLambda関数ARN。"
  value       = { for key, function in aws_lambda_function.this : key => function.arn }
}

output "lambda_execution_role_arns" {
  description = "Lambda識別子をキーとするLambda実行ロールARN。"
  value       = { for key, role in aws_iam_role.this : key => role.arn }
}
