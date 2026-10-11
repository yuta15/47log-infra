output "s3_bucket_name" {
  description = "配信ファイルのアップロード先。無効時はnull。"
  value       = try(aws_s3_bucket.this[0].bucket, null)
}

output "s3_bucket_arn" {
  description = "アップロード権限のIAMポリシーに利用するバケットARN。無効時はnull。"
  value       = try(aws_s3_bucket.this[0].arn, null)
}

output "cloudfront_distribution_id" {
  description = "キャッシュのInvalidationに利用するDistribution ID。無効時はnull。"
  value       = try(aws_cloudfront_distribution.this[0].id, null)
}

output "cloudfront_domain_name" {
  description = "CloudFrontの標準ドメイン名。無効時はnull。"
  value       = try(aws_cloudfront_distribution.this[0].domain_name, null)
}

output "frontend_url" {
  description = "フロントエンドの配信URL。無効時はnull。"
  value       = try("https://${aws_cloudfront_distribution.this[0].domain_name}", null)
}
