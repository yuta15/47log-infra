resource "aws_cognito_user_pool" "this" {
  name                     = var.project_name
  user_pool_tier           = "LITE"
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]
  tags                     = var.tags

  username_configuration {
    case_sensitive = false
  }

  # IdPがログインのたびに更新する属性はmutableにする。
  schema {
    name                = "email"
    attribute_data_type = "String"
    required            = true
    mutable             = true
    string_attribute_constraints {
      min_length = 1
      max_length = 2048
    }
  }

  schema {
    name                = "name"
    attribute_data_type = "String"
    required            = false
    mutable             = true
    string_attribute_constraints {
      min_length = 0
      max_length = 2048
    }
  }

  # SignUp APIによるローカルユーザーの自己登録を無効にする。
  admin_create_user_config {
    allow_admin_create_user_only = true
  }
}

resource "aws_cognito_user_pool_domain" "this" {
  domain                = var.cognito_domain
  user_pool_id          = aws_cognito_user_pool.this.id
  managed_login_version = 1 # Classic Hosted UI。LITEプランで利用する。
}

resource "aws_cognito_identity_provider" "this" {
  user_pool_id  = aws_cognito_user_pool.this.id
  provider_name = "Google"
  provider_type = "Google"
  provider_details = {
    client_id        = var.google_client_id
    client_secret    = var.google_client_secret
    authorize_scopes = "openid email profile"
  }
  attribute_mapping = {
    email = "email"
    name  = "name"
  }
}

resource "aws_cognito_user_pool_client" "this" {
  name         = "${var.project_name}-web"
  user_pool_id = aws_cognito_user_pool.this.id

  # ブラウザ向けpublic client。アプリ側ではPKCEを併用する。
  generate_secret                      = false
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["openid", "email", "profile"]
  callback_urls                        = var.callback_urls
  logout_urls                          = var.logout_urls
  supported_identity_providers         = [aws_cognito_identity_provider.this.provider_name]
  # 空にすると既定のSRP等が有効になるため、更新フローだけを明示する。
  explicit_auth_flows           = ["ALLOW_REFRESH_TOKEN_AUTH"]
  prevent_user_existence_errors = "ENABLED"
  enable_token_revocation       = true
  read_attributes               = ["email", "email_verified", "name"]
  write_attributes              = ["email", "name"]
}
