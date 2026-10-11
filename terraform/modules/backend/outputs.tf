output "api_id" {
  description = "HTTP APIのID。無効時はnull。"
  value       = try(aws_apigatewayv2_api.this[0].id, null)
}

output "api_endpoint" {
  description = "$defaultステージのHTTP APIエンドポイント。無効時はnull。"
  value       = try(aws_apigatewayv2_api.this[0].api_endpoint, null)
}

output "lambda_function_names" {
  description = "Lambda名をキーとするLambda関数名。無効時は空。"
  value       = { for key, function in aws_lambda_function.this : key => function.function_name }
}

output "lambda_function_arns" {
  description = "Lambda名をキーとするLambda関数ARN。無効時は空。"
  value       = { for key, function in aws_lambda_function.this : key => function.arn }
}

output "lambda_execution_role_arns" {
  description = "Lambda名をキーとするLambda実行ロールARN。無効時は空。"
  value       = { for key, role in aws_iam_role.this : key => role.arn }
}
