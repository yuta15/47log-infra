mock_provider "aws" {
  mock_resource "aws_cognito_user_pool" {
    defaults = {
      id       = "ap-northeast-1_test"
      endpoint = "cognito-idp.ap-northeast-1.amazonaws.com/ap-northeast-1_test"
      region   = "ap-northeast-1"
    }
  }
}

variables {
  project_name         = "47log-development"
  cognito_domain       = "47log-development-test"
  callback_urls        = ["http://localhost:3000/auth/callback"]
  logout_urls          = ["http://localhost:3000/"]
  google_client_id     = "example.apps.googleusercontent.com"
  google_client_secret = "mock-secret-not-a-real-credential"
}

run "google_only_client" {
  command = apply
  assert {
    condition = (
      aws_cognito_user_pool.this.name == var.project_name &&
      aws_cognito_user_pool.this.username_attributes == toset(["email"]) &&
      aws_cognito_identity_provider.this.provider_name == "Google" &&
      aws_cognito_user_pool_client.this.supported_identity_providers == toset(["Google"]) &&
      aws_cognito_user_pool.this.admin_create_user_config[0].allow_admin_create_user_only &&
      aws_cognito_user_pool_client.this.explicit_auth_flows == toset(["ALLOW_REFRESH_TOKEN_AUTH"]) &&
      !aws_cognito_user_pool_client.this.generate_secret &&
      aws_cognito_user_pool_client.this.allowed_oauth_flows == toset(["code"]) &&
      aws_cognito_user_pool_client.this.allowed_oauth_flows_user_pool_client &&
      aws_cognito_user_pool_client.this.callback_urls == var.callback_urls &&
      aws_cognito_user_pool_client.this.logout_urls == var.logout_urls &&
      output.jwt_authorizer.issuer == "https://cognito-idp.ap-northeast-1.amazonaws.com/ap-northeast-1_test" &&
      output.jwt_authorizer.audience == toset([aws_cognito_user_pool_client.this.id]) &&
      output.cognito_origin == "https://47log-development-test.auth.ap-northeast-1.amazoncognito.com" &&
      output.google_redirect_uri == "${output.cognito_origin}/oauth2/idpresponse"
    )
    error_message = "ローカル登録・パスワード認証を無効にし、Googleのみのpublic clientとJWT設定を生成する必要があります。"
  }
}

run "google_idp" {
  command = apply
  variables {
    google_client_id     = "example.apps.googleusercontent.com"
    google_client_secret = "mock-secret-not-a-real-credential"
  }
  assert {
    condition = (
      aws_cognito_identity_provider.this.provider_name == "Google" &&
      aws_cognito_identity_provider.this.user_pool_id == aws_cognito_user_pool.this.id &&
      aws_cognito_identity_provider.this.provider_type == "Google" &&
      aws_cognito_identity_provider.this.provider_details["client_id"] == var.google_client_id &&
      aws_cognito_identity_provider.this.provider_details["client_secret"] == var.google_client_secret &&
      aws_cognito_identity_provider.this.provider_details["authorize_scopes"] == "openid email profile" &&
      aws_cognito_identity_provider.this.attribute_mapping == tomap({ email = "email", name = "name" }) &&
      aws_cognito_user_pool_client.this.supported_identity_providers == toset(["Google"]) &&
      aws_cognito_user_pool_client.this.write_attributes == toset(["email", "name"])
    )
    error_message = "Google IdPの認証情報・属性とApp Clientの対応プロバイダーを設定する必要があります。"
  }
}

run "singleton_resources" {
  command = apply
  assert {
    condition = (
      aws_cognito_user_pool_domain.this.user_pool_id == aws_cognito_user_pool.this.id &&
      aws_cognito_user_pool_client.this.user_pool_id == aws_cognito_user_pool.this.id &&
      aws_cognito_identity_provider.this.user_pool_id == aws_cognito_user_pool.this.id &&
      aws_cognito_user_pool_domain.this.domain == var.cognito_domain &&
      output.user_pool_id == aws_cognito_user_pool.this.id &&
      output.user_pool_client_id == aws_cognito_user_pool_client.this.id
    )
    error_message = "モジュールの呼び出しにより4つのリソースが作成され、同じUser Poolに接続される必要があります。"
  }
}

run "google_without_secret" {
  command = plan
  variables { google_client_secret = null }
  expect_failures = [var.google_client_secret]
}

run "secret_without_google_id" {
  command = plan
  variables { google_client_id = null }
  expect_failures = [var.google_client_id]
}

run "empty_callbacks" {
  command = plan
  variables { callback_urls = [] }
  expect_failures = [var.callback_urls]
}

run "insecure_callback" {
  command = plan
  variables { callback_urls = ["http://app.example.com/callback"] }
  expect_failures = [var.callback_urls]
}

run "invalid_domain" {
  command = plan
  variables { cognito_domain = "https://example.com" }
  expect_failures = [var.cognito_domain]
}

run "missing_google_credentials" {
  command = plan
  variables {
    google_client_id     = null
    google_client_secret = null
  }
  expect_failures = [var.google_client_id, var.google_client_secret]
}

run "min_project_name_length" {
  command = plan
  variables { project_name = "a-1" }

  assert {
    condition = (
      aws_cognito_user_pool.this.name == var.project_name &&
      aws_cognito_user_pool_client.this.name == "${var.project_name}-web"
    )
    error_message = "許可したproject_nameをUser Pool名とClient名に使用する必要があります。"
  }
}

run "max_project_name_length" {
  command = plan
  variables { project_name = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" }

  assert {
    condition = (
      aws_cognito_user_pool.this.name == var.project_name &&
      aws_cognito_user_pool_client.this.name == "${var.project_name}-web"
    )
    error_message = "許可したproject_nameをUser Pool名とClient名に使用する必要があります。"
  }
}

run "blank_project_name" {
  command = plan
  variables { project_name = " " }
  expect_failures = [var.project_name]
}

run "short_project_name" {
  command = plan
  variables { project_name = "ab" }
  expect_failures = [var.project_name]
}

run "long_project_name" {
  command = plan
  variables { project_name = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" }
  expect_failures = [var.project_name]
}

run "dotted_project_name" {
  command = plan
  variables { project_name = "app.example.com" }
  expect_failures = [var.project_name]
}

run "uppercase_project_name" {
  command = plan
  variables { project_name = "App-example" }
  expect_failures = [var.project_name]
}

run "underscore_project_name" {
  command = plan
  variables { project_name = "app_example" }
  expect_failures = [var.project_name]
}

run "leading_hyphen" {
  command = plan
  variables { project_name = "-app" }
  expect_failures = [var.project_name]
}

run "trailing_hyphen" {
  command = plan
  variables { project_name = "app-" }
  expect_failures = [var.project_name]
}

run "reserved_prefix" {
  command = plan
  variables { project_name = "xn--app" }
  expect_failures = [var.project_name]
}

run "reserved_suffix" {
  command = plan
  variables { project_name = "app-s3alias" }
  expect_failures = [var.project_name]
}
