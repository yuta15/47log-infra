output "user_pool_id" {
  description = "Cognito User PoolのID。"
  value       = aws_cognito_user_pool.this.id
}

output "user_pool_client_id" {
  description = "アプリクライアントID。API GatewayのJWT audienceに使用する。"
  value       = aws_cognito_user_pool_client.this.id
}

output "jwt_authorizer" {
  description = "backendモジュールのjwt_authorizerに渡すissuerとaudience。"
  value = {
    issuer   = "https://${aws_cognito_user_pool.this.endpoint}"
    audience = toset([aws_cognito_user_pool_client.this.id])
  }
}

output "cognito_origin" {
  description = "Googleの承認済みJavaScript生成元に登録するCognitoのURL。"
  value       = "https://${aws_cognito_user_pool_domain.this.domain}.auth.${aws_cognito_user_pool.this.region}.amazoncognito.com"
}

output "google_redirect_uri" {
  description = "Googleの承認済みリダイレクトURIに登録するURL。"
  value       = "https://${aws_cognito_user_pool_domain.this.domain}.auth.${aws_cognito_user_pool.this.region}.amazoncognito.com/oauth2/idpresponse"
}
