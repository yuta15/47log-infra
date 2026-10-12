# registry モジュール

プライベート ECR リポジトリを1つ作成する。AWS provider のリージョン・認証は呼び出し元で設定する。

```hcl
module "registry" {
  source = "../../modules/registry"

  repository_name = "47log-production"
  tags = {
    Project     = "47log"
    Environment = "production"
  }
}
```

`repository_name` は必須、`tags` は省略時に空の map。
タグは上書き不可（IMMUTABLE）、暗号化は AES256、push 時のイメージスキャンを有効にする。

| output | 用途 |
| --- | --- |
| `repository_name` | リポジトリ名 |
| `repository_arn` | IAM ポリシーで使用する ARN |
| `repository_url` | コンテナイメージの push 先 URL |

```sh
make check MODULE=registry
```
