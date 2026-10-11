# backend

Lambdaの指定からHTTP APIのルートを自動作成するモジュール。
`lambdas`のキーが関数名になり、各Lambdaの`route_path`を入口として使う。
例えば`user-lambda`に`/user`を指定すると、同じLambdaへ向く`ANY /user`と`ANY /user/{proxy+}`を作成する。
LambdaごとにIAM実行ロール、CloudWatch Logs、API統合、呼び出し許可を1つずつ作成する。
ステージは`$default`のみで、自動デプロイする。

## 利用例

```hcl
module "backend" {
  source = "../../modules/backend"

  name = "47log-production-api"

  lambdas = {
    "user-lambda" = {
      route_path    = "/user"
      image_uri     = var.user_initial_image_uri
      authorization = "JWT"
      scopes        = ["users:read"]
      table_arns    = module.database.table_arns
    }
    "webhook-lambda" = {
      route_path    = "/webhook"
      image_uri     = var.webhook_initial_image_uri
      authorization = "NONE"
    }
  }

  jwt_authorizer = {
    issuer   = "https://cognito-idp.ap-northeast-1.amazonaws.com/ap-northeast-1_example"
    audience = ["example-app-client-id"]
  }

  enable_health_and_preflight_routes = true
  auxiliary_lambda_target           = "user-lambda"

  cors_configuration = {
    allow_origins = ["https://app.example.com"]
    max_age       = 3600
  }

  throttling = {
    rate_limit  = 100
    burst_limit = 200
  }

  tags = { Environment = "production" }
}
```

| Lambda | 自動作成する通常ルート | 認可 |
| --- | --- | --- |
| `user-lambda` | `ANY /user`、`ANY /user/{proxy+}` | JWT |
| `webhook-lambda` | `ANY /webhook`、`ANY /webhook/{proxy+}` | NONE |

Lambda名は環境間でも一意になるように指定する。
`route_path`には一意な固定パスを指定する。`/`以外の末尾スラッシュや`{proxy+}`などのパラメータは指定しない。
`/`を指定した場合は`ANY /`と`ANY /{proxy+}`を作成する。
入力のルート定義が変わっても、LambdaのリソースアドレスはLambda名で維持される。

## defaultルートだけにする場合

```hcl
lambdas = {
  "47log-production-api" = {
    route_path    = "$default"
    image_uri     = var.backend_initial_image_uri
    authorization = "JWT"
  }
}
```

`route_path = "$default"`では通常ルートは`$default`を1つだけ作成する。
`ANY /{proxy+}`などの通常ルートは追加しない。
JWT認可を使う場合は`cors_configuration`も指定し、認可不要の`OPTIONS /{proxy+}`を自動追加する。
プリフライトはAPI GatewayのCORS機能が応答するため、Lambda側の対応は不要。
ルート直下`/`へのプリフライトも必要なら`enable_root_preflight = true`で`OPTIONS /`を追加する。
NONEの場合はOPTIONSを自動追加しないため、health追加フラグもfalseならAPIルートは1つだけになる。

`$default`は通常パス用Mapと分離して展開し、API全体で最大1つとする。
`route_path`の重複は入力検証で拒否するため、複数Lambdaへの`$default`指定もできない。
通常パスとの混在も可能。

```hcl
lambdas = {
  default = { route_path = "$default", image_uri = var.backend_initial_image_uri }
  users   = { route_path = "/users", image_uri = var.user_initial_image_uri }
  visits  = { route_path = "/visits", image_uri = var.visit_initial_image_uri }
}
```

この例では`$default`、認可不要の`OPTIONS /{proxy+}`、usersとvisitsの各2つのANYルートを作成する。

## 認可と追加ルート

各Lambdaの`authorization`は`JWT`（既定値）または`NONE`。
完全一致と配下の両ルートには同じ認可・`scopes`を適用する。
JWTを使うLambdaがある場合は共通の`jwt_authorizer.issuer`と`audience`が必須。
トークンは`Authorization`ヘッダーから取得する。全LambdaがNONEならJWT設定を省略できる。
ルートMapを`locals`で展開し、認可の有無にかかわらず単一の`aws_apigatewayv2_route.this`を`for_each`で作成する。
Amazon Cognito User Poolは外部で作成し、そのissuer URLとアプリクライアントID（audience）を渡す。

認可不要のパスを明示する場合もLambda定義に`authorization = "NONE"`を指定する。

```hcl
lambdas = {
  users = {
    route_path = "/users"
    image_uri  = var.user_initial_image_uri
  }
  health = {
    route_path    = "/health"
    image_uri     = var.health_initial_image_uri
    authorization = "NONE"
  }
}
```

この例ではusersの2つのANYルートにJWT認可を適用し、healthの2つのANYルートは認可不要にする。

`enable_health_and_preflight_routes`の既定値はfalse。
trueの場合は認可不要の`GET /health`を追加する。
OPTIONSはこのフラグとは独立して、JWT認可付き`$default`がある場合だけ
認可不要の`OPTIONS /{proxy+}`を追加する。`OPTIONS /`は`enable_root_preflight = true`の場合のみ追加する。
`$default`がない場合や認可がNONEの場合は、rootフラグがtrueでもOPTIONSルートを追加しない。
`/health`はこのフラグを使う場合の予約パス。

healthは`auxiliary_lambda_target`で選択したLambdaへ統合し、追加のLambdaは作成しない。
Lambdaが1つなら投げ先の指定は不要。複数ある場合は`lambdas`のキーを指定する。
明示的なOPTIONSは`$default`のLambda統合へ向けるが、CORSプリフライトの応答はAPI Gatewayが行う。
healthの応答は投げ先のLambdaで実装する。healthの公開はGETのみで、`/health/`は別パスになる。

## Lambda設定とイメージ更新

各Lambdaの設定は以下の既定値を使う。

| 入力 | 既定値 |
| --- | --- |
| `architecture` | `x86_64` |
| `memory_size` | 256 MB |
| `timeout` | 30秒 |
| `timeout_milliseconds`（API統合） | 30000 ms |
| `environment_variables` | 空map |
| `table_arns` | 空map |
| `scopes` | 空集合 |

ログ保存期間は30日。`table_arns`で許可したテーブルへの読み書きとテーブル・インデックスのQuery/Scanのみを付与する。
空mapのLambdaにはDBポリシーを作成しない。ログ権限も関数ごとのロググループに限定する。

Lambdaはコンテナイメージ方式。初回作成前に同じリージョンのECRへ
Lambda Runtime Interface Clientを含むイメージをpushし、そのURIを`image_uri`に指定する。
DockerのビルドやpushはTerraformでは行わない。CPUアーキテクチャもイメージと一致させる。
ECRからイメージを取得する権限はLambdaサービスとデプロイ主体側で用意する。

`image_uri`は`lifecycle.ignore_changes`で更新対象から除外するため、作成後のイメージ更新はアプリ側CI/CDで行う。
タグの上書きだけではLambdaは更新されない。

```sh
aws lambda update-function-code \
  --function-name 47log-production-api \
  --image-uri "$IMAGE_URI" \
  --region ap-northeast-1
aws lambda wait function-updated-v2 \
  --function-name 47log-production-api \
  --region ap-northeast-1
```

デプロイロールにはECR push権限と、対象関数の`lambda:UpdateFunctionCode`、`lambda:GetFunction`を付与する。
これはLambda実行ロールとは別で、このモジュールでは作成しない。
再作成時には入力の初期イメージを使うため、そのイメージをECRに保持する。
Terraformはメモリ・IAM・環境変数などを引き続き管理する。

## CORS・スロットリング・出力

`cors_configuration`は省略時null。JWT認可付き`$default`を使う場合はAPI Gatewayでプリフライトを処理するため必須。
設定時は`allow_origins`が必須で、
`allow_methods`、`allow_headers`、`expose_headers`、`allow_credentials`、`max_age`を指定できる。
既定値はGET/HEAD/POST/PUT/PATCH/DELETE/OPTIONS、authorization/content-type、公開ヘッダー空、
資格情報false、キャッシュ秒数0。資格情報trueではoriginに`*`を指定できない。
CORS設定時はAPI Gatewayがpreflightに応答し、LambdaのCORSヘッダーは無視する。
クロスオリジンで使う場合は`cors_configuration`を指定する。Lambdaにプリフライト専用の処理は不要。
[AWSのCORS仕様](https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-cors.html)を参照。

`throttling`で全ルート共通の`rate_limit`（毎秒のリクエスト数）と`burst_limit`を設定する。
省略時はAPI Gatewayの既定値。0は無制限ではない。
スロットリングはベストエフォートで、アカウント・リージョン側の制限も適用される。

`api_id`、`api_endpoint`と、Lambda名をキーとする
`lambda_function_names`、`lambda_function_arns`、`lambda_execution_role_arns`を出力する。
Lambda呼び出し許可はこのAPIの`$default`ステージに限定する。
`enable_backend_modules = false`ではすべてのリソースを作成せず、APIの出力はnull、Lambdaのmapは空になる。

## 検証

```sh
terraform -chdir=terraform/modules/backend init -backend=false
terraform -chdir=terraform/modules/backend validate
terraform -chdir=terraform/modules/backend test
```

テストはモックAWSプロバイダーを使い、AWSリソースを作成しない。
