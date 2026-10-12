# development

ローカルから Cognito と ECR をデプロイする。リソース名は既定で `47log-development`、
タグの `Environment` は `development`。state はこのディレクトリの `terraform.tfstate` に保存する。

AWS 認証情報を設定したシェルで、以下を実行する。

```sh
cp terraform/environments/development/terraform.tfvars.example terraform/environments/development/terraform.tfvars
# terraform.tfvars の Cognito ドメイン・アプリ URL・Google Client ID を実値に変更する。
export TF_VAR_google_client_secret="<Google Client Secret>"

make develop-apply       # init → apply（確認なし）
make develop-push-image  # dummy image を build → ECR に push
# 両方を順番に実行する場合は make develop
make develop-destroy     # init → destroy（確認なし）
```

`dummy-v1` が ECR に存在する場合、image の build / push はスキップする。
Google OAuth の登録先 URL と Cognito の ID、ECR の push 先は
`terraform -chdir=terraform/environments/development output` で確認する。
`terraform.tfstate` はリソースの管理に必要なため、ローカルに保持する。
apply・destroy は `--auto-approve` で確認なしに実行する。
development の ECR は `force_delete = true` とし、Terraform がイメージを含めて削除する。
既存の ECR には一度 `make develop-apply` で設定を反映してから destroy を実行する。
