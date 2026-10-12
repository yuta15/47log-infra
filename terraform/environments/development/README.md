# development

ローカルからCognitoとECRをデプロイする。
stateはこのディレクトリの `terraform.tfstate` に保存するため、ローカルに保持する。

AWS認証情報を設定したシェルで、リポジトリルートから実行する。

```sh
cp terraform/environments/development/terraform.tfvars.example terraform/environments/development/terraform.tfvars
# terraform.tfvars の Cognito ドメイン・アプリ URL・Google Client ID を実値に変更する。
export TF_VAR_google_client_secret="<Google Client Secret>"

make develop             # apply と dummy image の push
make develop-apply       # apply のみ
make develop-push-image  # image の build と push のみ
make develop-destroy     # リソースの削除
```

apply・destroyは確認なしで実行する。destroyではECR内のイメージも削除する。
既存ECRには一度 `make develop-apply` で削除設定を反映してからdestroyを実行する。
`dummy-v1` が存在する場合、imageのbuild・pushはスキップする。

CognitoのID、Google OAuthの登録先URL、ECRのpush先を確認する：

```sh
terraform -chdir=terraform/environments/development output
```
