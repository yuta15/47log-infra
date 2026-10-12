variable "aws_region" {
  description = "productionをデプロイするAWSリージョン。"
  type        = string
  default     = "ap-northeast-1"
}

variable "project_name" {
  description = "productionのCognito User Pool名。"
  type        = string
  default     = "47log-production"
}

variable "cognito_domain" {
  description = "Cognito Hosted UIのドメイン接頭辞。リージョン内で一意の値を指定する。"
  type        = string
}

variable "callback_urls" {
  description = "Cognitoからアプリへ戻るログイン後のURL。"
  type        = set(string)
}

variable "logout_urls" {
  description = "ログアウト後に戻るアプリのURL。"
  type        = set(string)
  default     = []
}

variable "google_client_id" {
  description = "Googleで作成したOAuthクライアントID。"
  type        = string
}

variable "google_client_secret" {
  description = "Google OAuthクライアントSecret。TF_VAR_google_client_secret等で外部から渡す。"
  type        = string
  sensitive   = true
}
