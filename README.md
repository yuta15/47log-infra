# 47log-infra

47log の AWS インフラを Terraform で管理するリポジトリ。

## 開発

Terraform のバージョンは `terraform/environments/production/.terraform-version`、
TFLint のバージョンは `.tflint-version` を使用する。

```sh
make fmt MODULE=auth    # 整形
make check MODULE=auth  # fmt・lint・validate・モックテスト
make check MODULE=all   # 全モジュールを検査
```

`MODULE` を省略すると `frontend` が対象になる。
各モジュールの利用方法は `terraform/modules/` 配下の README を参照。

## デプロイ

development はローカルで手動実行する。[実行手順](terraform/environments/development/README.md)を参照。

GitHub Actions の [Provision production infrastructure](.github/workflows/provision-infrastructure.yaml)
を main ブランチから手動実行する。push による自動デプロイは現在無効。

Repository Variable の `environment` に `production` を設定し、
GitHub Environment `production` に以下の値を設定する。

| 種類 | 名前 | 値 |
| --- | --- | --- |
| Variable | `BACKEND_BUCKET` | tfstate 保存用の既存 S3 バケット名 |
| Variable | `AWS_REGION` | 例: `ap-northeast-1` |
| Variable | `PROJECT_NAME` | 例: `47log-production` |
| Variable | `COGNITO_DOMAIN` | Cognito Hosted UI のドメイン接頭辞 |
| Variable | `CALLBACK_URLS` | JSON 配列。例: `["https://app.example.com/auth/callback"]` |
| Variable | `LOGOUT_URLS` | JSON 配列。未使用なら `[]` |
| Variable | `GOOGLE_CLIENT_ID` | Google OAuth Client ID |
| Secret | `GOOGLE_CLIENT_SECRET` | Google OAuth Client Secret |
| Variable | `TERRAFORM_ROLE_ARN` | GitHub OIDC 認証用の AWS IAM role ARN |

state は指定バケットの `47log/production/infra/terraform.tfstate` に保存する。
