# frontend モジュール

非公開 S3 の SPA を CloudFront の標準ドメインで配信する。
環境側の呼び出し・provider 設定・配信ファイルのアップロードは、呼び出し側で管理する。

リソースの作成有無はモジュールの呼び出し元で制御する。内部に有効化フラグは設けない。

## 呼び出し側から受け取る設定

| 引数 | 用途 |
| --- | --- |
| `bucket_name` | 環境ごとに一意な S3 バケット名。必須。 |
| `tags` | プロジェクト名・環境名など。省略時は空の map。 |

```hcl
module "frontend" {
  source = "../../modules/frontend"

  bucket_name = "47log-development-frontend-123456789012"
  tags = {
    Project     = "47log"
    Environment = "development"
  }
}
```

バケット名の例は呼び出し側で決めた一意な名前に置き換える。
リージョンと認証情報は、呼び出し側の AWS provider で設定する。

## モジュール側で固定する設定

- S3 の公開アクセスをすべてブロックし、ACL を無効化、SSE-S3 で暗号化する。
- OAC は常に SigV4 署名を行う。バケットポリシーは当該 Distribution の `s3:GetObject` を許可する。
- AWS サービス以外からの S3 HTTP リクエストを拒否する。
- CloudFront は GET/HEAD を配信し、HTTP は HTTPS にリダイレクトする。
- AWS 管理の `SecurityHeadersPolicy` と CloudFront の標準証明書を利用する。
- SPA の最終パス要素に拡張子がなければ `/index.html` に書き換える。`/logs` や `/logs/123` の直接アクセスに対応する。ドットを含む最終パス要素はファイルとして扱う。
- キャッシュキーに Cookie・クエリ文字列を含めない。最小・既定 TTL はゼロ、最大 TTL は1年とし、オブジェクトの `Cache-Control` に従う。
- `force_destroy` は無効。ファイルが残ったバケットの削除を自動では行わない。

## outputs とデプロイ側の設定

| output | 用途 |
| --- | --- |
| `s3_bucket_name` | 配信ファイルのアップロード先 |
| `s3_bucket_arn` | アップロード権限の IAM ポリシー。オブジェクト操作では `/*` を付加する。 |
| `cloudfront_distribution_id` | キャッシュの Invalidation |
| `cloudfront_domain_name` | CloudFront の標準ドメイン |
| `frontend_url` | HTTPS の配信 URL |

アップロード権限はデプロイ用 IAM ロール側で管理する。
`index.html` は `Cache-Control: no-cache`、内容のハッシュをファイル名に含む JS/CSS は `Cache-Control: public, max-age=31536000, immutable` を設定する想定。
ヘッダー未指定のファイルは CloudFront で継続キャッシュしないため、S3 へのリクエストが増える。

料金は利用量と選択する料金プランによる。[S3 料金](https://aws.amazon.com/s3/pricing/)・[CloudFront 料金](https://aws.amazon.com/cloudfront/pricing/)を参照。

## チェック

リポジトリルートから実行する。

```sh
make fmt     # 整形
make lint    # 整形チェックと TFLint
make check   # lint、Terraform validate、モックテスト
```

TFLint は Terraform の推奨ルールと AWS のルールを利用する。
S3 と CloudFront のファイル分割を維持するため、標準ファイル構成を強制するルールだけ無効化する。
モックテストは実際の AWS リソースを作成せず、単一リソースの作成、S3 のアクセス制限、必須入力、outputs を検証する。
