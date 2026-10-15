# frontend

非公開S3に配置したSPAをCloudFrontの標準ドメインで配信する。
配信ファイルのアップロードは呼び出し側で行う。

```hcl
module "frontend" {
  source = "../../modules/frontend"

  project_name = "47log-development-frontend-123456789012"
  tags = {
    Project     = "47log"
    Environment = "development"
  }
}
```

`project_name` をS3バケット名に使用するため、一意な名前を指定する。
小文字英数字・ハイフンの3〜60文字で、先頭・末尾は英数字とする。

## 配信とキャッシュ

HTTPはHTTPSにリダイレクトする。
最終パス要素に拡張子がなければ `/index.html` に書き換え、SPAの直接アクセスに対応する。
ドットを含む最終パス要素はファイルとして扱う。

キャッシュキーにCookie・クエリ文字列を含めず、Managed-CachingOptimized を使用する。
上記に伴い各ファイルの Cache-Control に基づいてキャッシュを制御する。
ヘッダー未指定の場合はデフォルトTTLの86,400秒（24時間）が適用されるため、必要に応じてアップロード時に Cache-Control を設定する。

| ファイル | Cache-Control |
| --- | --- |
| `index.html` | `no-cache` |
| ファイル名に内容のハッシュを含むJS/CSS | `public, max-age=31536000, immutable` |

ヘッダー未指定のファイルは継続キャッシュしない。
バケットを削除する場合は、先に配信ファイルを削除する。

## 出力

| output | 用途 |
| --- | --- |
| `s3_bucket_name` | 配信ファイルのアップロード先 |
| `s3_bucket_arn` | バケットARN |
| `cloudfront_distribution_id` | キャッシュのInvalidation |
| `cloudfront_domain_name` | CloudFrontの標準ドメイン |
| `frontend_url` | HTTPSの配信URL |
