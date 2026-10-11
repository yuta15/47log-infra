# auth

Cognito User Pool、ブラウザ用App Client、Hosted UIドメインを作成する。
ログインはGoogle専用。Google IdPを作成し、App Clientの対応プロバイダーをGoogleだけにする。
Google Cloud側のProjectやOAuthクライアントの作成はこのモジュールでは行わない。

```hcl
module "auth" {
  source = "../../modules/auth"

  project_name        = "47log-development"
  cognito_domain      = "47log-development"
  callback_urls       = ["https://app.example.com/auth/callback"]
  logout_urls         = ["https://app.example.com/"]

  google_client_id     = var.google_client_id
  google_client_secret = var.google_client_secret
  tags                = { Environment = "development" }
}

# backendモジュールの入力に使用する。
# jwt_authorizer = module.auth.jwt_authorizer
```

`google_client_id`と`google_client_secret`の両方が必須。
Secretはsensitive入力だがTerraform Stateにも保存されるため、
ソースに記載せずCIの秘密変数などから渡し、Stateへのアクセスも制限する。

ユーザープール名には`project_name`をそのまま使用し、Client名には`-web`を付ける。
Googleのemailとnameを更新可能な標準属性へマッピングする。
Cognitoのローカルユーザー登録とSRP・パスワード認証は無効にする。
`explicit_auth_flows`はトークン更新のみを許可し、Hosted UIにもCognitoのログインを表示しない。
Google初回ログイン時のユーザー作成は引き続き行われる。
[自己登録を無効にした場合の外部IdPログイン](https://docs.aws.amazon.com/cognito/latest/developerguide/how-to-create-user-accounts.html)を参照。
App ClientはSecretを生成しないpublic clientで、認可コードフローのみを許可する。
アプリケーションではPKCEを併用する。スコープはopenid・email・profile。
GoogleのOAuthクライアントSecretとCognito App ClientのSecretは別のものである。

LITEプランとClassic Hosted UI（version 1）を使用する。
`cognito_domain`はカスタムドメインではなく接頭辞で、リージョン内で一意の値が必要。

`callback_urls`はCognitoからアプリへ戻るURLであり、Googleへ登録するURIとは異なる。
Google側には次のoutputsを登録する。

- 承認済みJavaScript生成元：`cognito_origin`
- 承認済みリダイレクトURI：`google_redirect_uri`（Cognitoドメインの`/oauth2/idpresponse`）

Cognito作成前に、Google OAuthクライアントへ予定のCognito URLを登録してClient IDとSecretを取得する。
生成元は`https://{cognito_domain}.auth.{AWSリージョン}.amazoncognito.com`、
リダイレクトURIはそのURLの`/oauth2/idpresponse`。作成後にoutputsと一致することを確認する。
アプリから`/oauth2/authorize`へ遷移する際に`identity_provider=Google`を付けるとGoogleへ直接遷移できる。
[Google IdPの登録手順](https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pools-social-idp.html)を参照。

`user_pool_id`、`user_pool_client_id`、backendに直接渡せる`jwt_authorizer`も出力する。
リソースの作成有無は呼び出し元のmoduleブロックで制御する。
モジュール内部の有効化フラグは設けない。

```sh
terraform -chdir=terraform/modules/auth init -backend=false
terraform -chdir=terraform/modules/auth validate
terraform -chdir=terraform/modules/auth test
```

テストはモックAWSプロバイダーを使用する。実AWSへのapplyは行わない。
