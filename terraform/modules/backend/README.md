# backend

コンテナイメージの Lambda と HTTP API を作成する。
`route_path = "/user"` から `ANY /user` と `ANY /user/{proxy+}` を作成する。

## 利用例

```hcl
module "backend" {
  source = "../../modules/backend"

  project_name = "47log-production-api"
  lambdas = {
    users = {
      route_path = "/users"
      image_uri  = var.user_initial_image_uri
      table_arns = module.database.table_arns
    }
    webhook = {
      route_path    = "/webhook"
      image_uri     = var.webhook_initial_image_uri
      authorization = "NONE"
    }
  }

  jwt_authorizer = module.auth.jwt_authorizer
  public_routes  = { "GET /health" = "users" }

  cors_configuration = {
    allow_origins = ["https://app.example.com"]
  }
  throttling = {
    rate_limit  = 100
    burst_limit = 200
  }
  tags = { Environment = "production" }
}
```

## ルートと認可

`lambdas` は1件以上必須。`route_path` は一意な固定パスか `$default` を指定する。
`/` 以外の末尾スラッシュやパスパラメータは指定できない。
`$default` はAPI全体で1つだけ指定でき、通常パスと混在できる。

`authorization` は `JWT`（既定値）または `NONE`。
JWTを使う場合は `jwt_authorizer` が必須で、`scopes` も指定できる。
トークンは `Authorization` ヘッダーから取得する。

`public_routes` は既存Lambdaの特定のエンドポイントを認可不要にする。
キーには GET/HEAD/POST/PUT/PATCH/DELETE と固定パス、値には `lambdas` のキーを指定する。
healthの応答はアプリケーションで実装する。

クロスオリジンで使う場合は `cors_configuration.allow_origins` を指定する。
JWT付き `$default` とCORSを併用すると、認可不要の `OPTIONS /` と `OPTIONS /{proxy+}` を自動追加する。
プリフライトはAPI Gatewayが処理するため、Lambda側の対応は不要。
`allow_credentials = true` ではoriginに `*` を指定できない。

`throttling` は全ルート共通。0は無制限ではない。

## Lambdaとイメージ更新

関数名は `${project_name}-${lambdasのキー}`。
英数字・ハイフン・アンダースコアを使い、結合後の名前を64文字以内にする。
設定の既定値は [variables.tf](variables.tf) を参照。
`table_arns` にはLambdaが読み書きするDynamoDBテーブルを指定する。
API統合のタイムアウトは30秒で、Lambdaの `timeout` とは独立している。

初回作成前に、Lambda対応イメージを同じリージョンのECRへpushし、`image_uri` に指定する。
CPUアーキテクチャはイメージと一致させる。
作成後のイメージ更新はTerraformの管理対象外なので、アプリ側CI/CDで実行する。
タグの上書きだけではLambdaは更新されない。

```sh
aws lambda update-function-code \
  --function-name 47log-production-api-users \
  --image-uri "$IMAGE_URI" \
  --region ap-northeast-1
aws lambda wait function-updated-v2 \
  --function-name 47log-production-api-users \
  --region ap-northeast-1
```

再作成時には入力の `image_uri` を使うため、そのイメージをECRに保持する。

## 出力とログ

出力は [outputs.tf](outputs.tf) を参照。
Lambdaログは `/aws/lambda/${project_name}-${key}` に30日、
APIアクセスログは `/aws/apigateway/${project_name}` に14日保持する。

## 既存環境の更新

旧healthフラグは必要に応じて `public_routes` に置き換える。
関数名やロググループ名の変更は再作成を伴うため、planで確認し、必要なログを退避する。
旧Lambda名を参照するCI/CDや外部設定も更新する。
