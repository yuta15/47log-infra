output "user_pool_id" {
  description = "Cognito User PoolのID。"
  value       = module.auth.user_pool_id
}

output "user_pool_client_id" {
  description = "アプリで使用するCognito App ClientのID。"
  value       = module.auth.user_pool_client_id
}

output "cognito_origin" {
  description = "Googleの承認済みJavaScript生成元に登録するURL。"
  value       = module.auth.cognito_origin
}

output "google_redirect_uri" {
  description = "Googleの承認済みリダイレクトURIに登録するURL。"
  value       = module.auth.google_redirect_uri
}

output "repository_name" {
  description = "ECRリポジトリ名。"
  value       = module.registry.repository_name
}

output "repository_url" {
  description = "コンテナイメージのpush先URL。"
  value       = module.registry.repository_url
}
