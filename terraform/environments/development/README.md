# development

ローカルから Cognito と ECR をデプロイする。リソース名は既定で `47log-development`、
タグの `Environment` は `development`。state はこのディレクトリの `terraform.tfstate` に保存する。

AWS 認証情報を設定したシェルで、以下を実行する。

```sh
cd terraform/environments/development
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars の Cognito ドメイン・アプリ URL・Google Client ID を実値に変更する。
export TF_VAR_google_client_secret="<Google Client Secret>"

terraform init -lockfile=readonly
terraform fmt -check
terraform validate
terraform plan -out=terraform.tfplan
terraform apply terraform.tfplan
```

Google OAuth の登録先 URL と Cognito の ID、ECR の push 先は `terraform output` で確認する。
`terraform.tfstate` はリソースの管理に必要なため、ローカルに保持する。
