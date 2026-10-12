variable "project_name" {
  description = "Cognito User Pool名。環境を含むプロジェクト名をそのまま使用する。"
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,58}[a-z0-9]$", var.project_name))
    error_message = "project_name はfrontendと共通の命名規則に従い、3〜60文字の小文字英数字・ハイフンとし、先頭と末尾は英数字にしてください。"
  }

  validation {
    condition = try(
      !anytrue([for prefix in ["xn--", "sthree-", "amzn-s3-demo-"] : startswith(var.project_name, prefix)]) &&
      !anytrue([for suffix in ["-s3alias", "--ol-s3", "--x-s3", "--table-s3", "-an"] : endswith(var.project_name, suffix)]),
      false
    )
    error_message = "project_name にS3の予約済み接頭辞・接尾辞は使用できません。"
  }
}

variable "cognito_domain" {
  description = "Cognito Hosted UIのドメイン接頭辞（例: 47log-development）。リージョン内で一意の値を指定する。"
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", var.cognito_domain))
    error_message = "cognito_domainは1〜63文字の小文字英数字・ハイフンで、先頭と末尾は英数字にしてください。"
  }
}

variable "callback_urls" {
  description = "Cognitoからアプリへのログイン後のリダイレクトURL。GoogleからCognitoへのURIとは別。"
  type        = set(string)
  nullable    = false

  validation {
    condition = length(var.callback_urls) > 0 && alltrue([
      for url in var.callback_urls : can(regex("^https://[^/?#]+([/?][^#]*)?$|^http://localhost(:[0-9]+)?([/?][^#]*)?$", url))
    ])
    error_message = "callback_urlsにはHTTPS URL（ローカル開発のみhttp://localhostも可）を1つ以上指定してください。フラグメントは指定できません。"
  }
}

variable "logout_urls" {
  description = "ログアウト後に戻るアプリのURL。"
  type        = set(string)
  default     = []
  nullable    = false

  validation {
    condition = alltrue([
      for url in var.logout_urls : can(regex("^https://[^/?#]+([/?][^#]*)?$|^http://localhost(:[0-9]+)?([/?][^#]*)?$", url))
    ])
    error_message = "logout_urlsにはHTTPS URL（ローカル開発のみhttp://localhostも可）を指定してください。"
  }
}

variable "google_client_id" {
  description = "Googleで作成したOAuthクライアントID。必須。"
  type        = string

  validation {
    condition     = try(length(trimspace(var.google_client_id)) > 0, false)
    error_message = "空でないgoogle_client_idを指定してください。"
  }
}

variable "google_client_secret" {
  description = "Google OAuthクライアントSecret。Client IDとセットで外部から渡す。Terraform Stateにも保存される。"
  type        = string
  sensitive   = true

  validation {
    condition     = try(length(trimspace(var.google_client_secret)) > 0, false)
    error_message = "空でないgoogle_client_secretを指定してください。"
  }
}

variable "tags" {
  description = "Cognito User Poolのタグ。"
  type        = map(string)
  default     = {}
}
