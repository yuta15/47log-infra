# auth

Googleログイン用の Cognito User Pool、App Client、Hosted UI を作成する。
Google OAuthクライアントは事前にGoogle Cloudで作成する。

```hcl
module "auth" {
  source = "../../modules/auth"

  project_name         = "47log-development"
  cognito_domain       = "47log-development"
  callback_urls        = ["https://app.example.com/auth/callback"]
  logout_urls          = ["https://app.example.com/"]
  google_client_id     = var.google_client_id
  google_client_secret = var.google_client_secret
  tags                 = { Environment = "development" }
}
```

`google_client_id` と `google_client_secret` は必須。
Secretはソースに記載せず、環境変数やCIの秘密変数から渡す。Terraform Stateにも保存される。
アプリケーションでは認可コードフローとPKCEを使用する。

`cognito_domain` はリージョン内で一意なドメイン接頭辞。
Google OAuthクライアントには以下を登録する。

| Googleの設定 | 登録値 |
| --- | --- |
| 承認済みJavaScript生成元 | `https://{cognito_domain}.auth.{AWSリージョン}.amazoncognito.com` |
| 承認済みリダイレクトURI | 上記URLの `/oauth2/idpresponse` |

作成後は出力の `cognito_origin` と `google_redirect_uri` で登録値を確認する。
`callback_urls` はCognitoからアプリへ戻るURLを指定する。

backendの認可設定には `module.auth.jwt_authorizer` を渡す。
その他の入力・出力は [variables.tf](variables.tf) と [outputs.tf](outputs.tf) を参照。
