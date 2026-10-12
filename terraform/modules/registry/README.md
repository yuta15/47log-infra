# registry

プライベート ECR リポジトリを1つ作成する。

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
`force_delete` は既定で `false`。`true` にするとイメージを含めてリポジトリを削除できる。
タグは上書き不可（IMMUTABLE）、暗号化は AES256、push 時のイメージスキャンを有効にする。

| output | 用途 |
| --- | --- |
| `repository_name` | リポジトリ名 |
| `repository_arn` | リポジトリ ARN |
| `repository_url` | コンテナイメージの push 先 URL |
