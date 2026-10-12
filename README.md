# 47log-infra
47log infra repositroy

## Terraformモジュールの開発

`MODULE`で対象モジュールを指定する。省略時は既存CIと同じ`frontend`。
`MODULE=all`では`terraform/modules/`直下のTerraformファイルがある全モジュールを処理する。
現在の対象は`auth`、`backend`、`database`、`frontend`。新しいモジュールも自動的に対象へ追加される。
モジュールの入力・固定設定・outputsは各モジュールのREADMEを参照。

Terraformは環境単位でバージョン管理する。productionの実行バージョンは
`terraform/environments/production/.terraform-version`、Terraform・Providerの制約は同ディレクトリの
`versions.tf`、Providerの選択結果は`.terraform.lock.hcl`で管理する。
各モジュールの`versions.tf`は互換性を示す制約として維持する。
TFLintはリポジトリ共通の`.tflint-version`を使用する。
TFLint の導入方法は [公式 README](https://github.com/terraform-linters/tflint#installation) を参照。

```sh
make fmt     # 整形
make lint    # 整形チェックと TFLint
make check   # lint、構文検証、AWS を使わないモックテスト

make fmt MODULE=auth
make lint MODULE=backend
make check MODULE=frontend

make fmt MODULE=all
make lint MODULE=all
make check MODULE="auth backend"  # 複数指定も可能
```

トップのMakefileはモジュールの検査用途。Terraformをproductionディレクトリから起動し、
ローカルのバージョン管理ツールが同ディレクトリの`.terraform-version`を参照できるようにする。
CIも同ファイルからTerraformのバージョンを読み込む。
初回実行時にlint pluginとAWS providerをダウンロードする。
モジュール単体の検査で生成するlock fileはGit管理対象外とする。
`fmt-check`、`tflint`、`init`、`validate`、`test`にも同じ`MODULE`指定が使える。
不明なモジュール名や空指定はエラーになる。検査エラーがあれば処理を停止する。
GitHub Actionsでも同じ`make check`を実行し、frontendを検査する。

## productionのTerraform実行

```sh
cd terraform/environments/production
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvarsのドメイン・URL・Google Client IDを実値へ変更する。
# Google SecretはTF_VAR_google_client_secret等で外部から渡す。
terraform init
terraform plan
```

productionでは現在authモジュールのみを呼び出す。ログインはGoogle専用。
Googleへ登録する生成元・リダイレクトURIとCognitoのPool・Client IDをoutputsで公開する。

`.terraform.lock.hcl`は環境のProviderバージョンを固定するためGitで管理する。
デプロイ操作は環境ディレクトリから実行する。
