output "s3_bucket_name" {
  description = "配信ファイルのアップロード先。"
  value       = aws_s3_bucket.this.bucket
}

output "s3_bucket_arn" {
  description = "アップロード権限のIAMポリシーに利用するバケットARN。"
  value       = aws_s3_bucket.this.arn
}

output "cloudfront_distribution_id" {
  description = "キャッシュのInvalidationに利用するDistribution ID。"
  value       = aws_cloudfront_distribution.this.id
}

output "cloudfront_domain_name" {
  description = "CloudFrontの標準ドメイン名。"
  value       = aws_cloudfront_distribution.this.domain_name
}

output "frontend_url" {
  description = "フロントエンドの配信URL。"
  value       = "https://${aws_cloudfront_distribution.this.domain_name}"
}
