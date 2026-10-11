# 47log-infra
47log infra repositroy

## frontend の開発

現時点のチェック対象は `terraform/modules/frontend` のみ。
モジュールの入力・固定設定・outputs は [frontend の README](terraform/modules/frontend/README.md) を参照。

Terraform は `.terraform-version`、TFLint は `.tflint-version` に記載したバージョンを利用する。
TFLint の導入方法は [公式 README](https://github.com/terraform-linters/tflint#installation) を参照。

```sh
make fmt     # 整形
make lint    # 整形チェックと TFLint
make check   # lint、構文検証、AWS を使わないモックテスト
```

初回実行時に lint plugin と AWS provider をダウンロードする。
GitHub Actions でも同じ `make check` を実行する。
