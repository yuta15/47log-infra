# backend

Lambdaの指定からHTTP APIのルートを自動作成するモジュール。
関数名は`${name}-${lambdasのキー}`となり、各Lambdaの`route_path`を入口として使う。
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

  # 既存Lambdaで処理するGET /healthだけを認可不要にする（省略可能）。
  public_routes = { "GET /health" = "user-lambda" }

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

`name`には`47log-development-api`、`47log-production-api`のような環境別の値を指定する。
`name`とLambdaキーは英数字・ハイフン・アンダースコアのみで、結合後の関数名は64文字以内にする。
IAM Roleの名前にも同じ接頭辞（長い場合は先頭26文字）と一意なサフィックスを使う。
`route_path`には一意な固定パスを指定する。`/`以外の末尾スラッシュや`{proxy+}`などのパラメータは指定しない。
`/`を指定した場合は`ANY /`と`ANY /{proxy+}`を作成する。
入力のルート定義が変わっても、LambdaのリソースアドレスはMapのキーで維持される。

## defaultルートだけにする場合

```hcl
lambdas = {
  api = {
    route_path    = "$default"
    image_uri     = var.backend_initial_image_uri
    authorization = "JWT"
  }
}
```

`route_path = "$default"`では通常ルートは`$default`を1つだけ作成する。
`ANY /{proxy+}`などの通常ルートは追加しない。
JWT認可付き`$default`と`cors_configuration`が両方ある場合、認可不要の
`OPTIONS /{proxy+}`と`OPTIONS /`を自動追加する。
ルート直下`/`も含めてプリフライトはAPI GatewayのCORS機能が応答するため、Lambda側の対応は不要。
OPTIONSは同じLambda Integrationを参照するが、CORSプリフライトはLambdaを呼び出さずAPI Gatewayで処理する。
CORSがnull、または`$default`がNONEの場合はOPTIONSを自動追加しない。
CORSがnullの場合、通常ルートは`$default`の1つだけとなる。

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

CORS設定時、この例では`$default`、認可不要の`OPTIONS /{proxy+}`と`OPTIONS /`、usersとvisitsの各2つのANYルートを作成する。

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

`GET /health`は自動生成しない。healthの応答はアプリケーションで実装する。
既存Lambdaの特定のエンドポイントだけを公開する場合は、次のMapを追加できる。

```hcl
public_routes = { "GET /health" = "api" }
```

キーはHTTPメソッドと固定パス、値は`lambdas`のキー。
GET/HEAD/POST/PUT/PATCH/DELETEを指定でき、指定したルートだけ`NONE`となる。
`ANY`、パスパラメータ、OPTIONSの指定には対応しない。
`GET /health`は`ANY /health`や`$default`より優先され、他のメソッドや配下のパスの認可は変更しない。
追加のLambda・Integrationは作成しない。公開ルートはセキュリティ上の例外なので明示的に指定する。
通常のパスルートと`$default`が混在する場合は、API Gatewayがより具体的なルートを優先する。

## Lambda設定とイメージ更新

各Lambdaの設定は以下の既定値を使う。

| 入力 | 既定値 |
| --- | --- |
| `architecture` | `x86_64` |
| `memory_size` | 256 MB |
| `timeout` | 30秒 |
| `environment_variables` | 空map |
| `table_arns` | 空map |
| `scopes` | 空集合 |

API統合のタイムアウトは30,000ms固定。Lambdaの`timeout`とは独立している。
Lambdaログは`/aws/lambda/${name}-${key}`で30日保持する。`table_arns`で許可したテーブルへの読み書きとテーブル・インデックスのQuery/Scanのみを付与する。
空mapのLambdaにはDBポリシーを作成しない。ログ権限も関数ごとのロググループに限定する。
DynamoDB操作は既存の読み書き権限を維持する。読み取り専用Lambdaでは書き込み操作、
全件走査をしないLambdaではScan、不要ならBatch操作やDescribeTableなどを削減できる。
今回はアプリの利用操作が未確定のため権限を一律削除せず、汎用IAMポリシー入力も追加しない。

Lambdaはコンテナイメージ方式。初回作成前に同じリージョンのECRへ
Lambda Runtime Interface Clientを含むイメージをpushし、そのURIを`image_uri`に指定する。
DockerのビルドやpushはTerraformでは行わない。CPUアーキテクチャもイメージと一致させる。
ECRからイメージを取得する権限はLambdaサービスとデプロイ主体側で用意する。

`image_uri`は`lifecycle.ignore_changes`で更新対象から除外するため、作成後のイメージ更新はアプリ側CI/CDで行う。
タグの上書きだけではLambdaは更新されない。

```sh
aws lambda update-function-code \
  --function-name 47log-production-api-api \
  --image-uri "$IMAGE_URI" \
  --region ap-northeast-1
aws lambda wait function-updated-v2 \
  --function-name 47log-production-api-api \
  --region ap-northeast-1
```

デプロイロールにはECR push権限と、対象関数の`lambda:UpdateFunctionCode`、`lambda:GetFunction`を付与する。
これはLambda実行ロールとは別で、このモジュールでは作成しない。
再作成時には入力の初期イメージを使うため、そのイメージをECRに保持する。
Terraformはメモリ・IAM・環境変数などを引き続き管理する。

## CORS・スロットリング・出力

`cors_configuration`は省略時null。クロスオリジンで使う場合に指定する。
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

`api_id`、`api_endpoint`と、Lambda識別子をキーとする
`lambda_function_names`、`lambda_function_arns`、`lambda_execution_role_arns`を出力する。
Lambda呼び出し許可はこのAPIの`$default`ステージに限定する。
モジュールの有効・無効は呼び出し元のmoduleブロックで管理する。
`lambdas`は1件以上必須で、無効化用の変数や出力のnull処理は設けない。

## APIアクセスログ

`/aws/apigateway/${name}`にLambdaログと分離して14日保持する。
`$default` StageのアクセスログはJSON形式で、requestId、routeKey、status、responseLatency、
integrationStatus、requestTime、httpMethod、responseLengthを記録する。
値が存在しない場合もJSONを壊さないよう、数値も文字列として出力する。
トークン、ヘッダー、JWT claims、リクエスト・レスポンス本文は出力しない。
[AWSのHTTP APIログ変数](https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-logging-variables.html)を使用する。

## 既存Stateからの移行

`enable_backend_modules`、`enable_health_and_preflight_routes`、`auxiliary_lambda_target`、
`enable_root_preflight`と各Lambdaの`timeout_milliseconds`入力は削除した。
既存のhealthフラグは必要に応じて`public_routes = { "GET /health" = "Lambdaのキー" }`へ置き換える。

APIとStageの`this[0]`から`this`への変更は`moved`ブロックで引き継ぐ。
Mapのキーを維持しても、Lambdaの関数名とロググループ名、IAM Roleの名前の変更は再作成を伴う。
Lambda Permissionや関連ポリシーも追随して変更され、Integrationの参照先も更新される。
ロググループの再作成により旧ログが削除される可能性があるため、必要なら事前に退避する。
旧Lambda名を参照するアプリCI/CDや外部設定も、新しい`lambda_function_names`の値へ更新する。
再作成時は現在デプロイ済みのイメージではなく入力の`image_uri`で作成するため、
適切なイメージを指定し、必要に応じてアプリCI/CDで再デプロイする。
実環境のplanで再作成や停止時間を確認してから移行する。この変更作業ではapply/destroyを実行しない。

## 検証

```sh
terraform fmt -recursive -check
terraform -chdir=terraform/modules/backend init -backend=false
terraform -chdir=terraform/modules/backend validate
terraform -chdir=terraform/modules/backend test
```

テストはモックAWSプロバイダーを使い、AWSリソースを作成しない。
