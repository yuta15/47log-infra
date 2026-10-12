output "repository_name" {
  description = "ECRリポジトリ名。"
  value       = aws_ecr_repository.this.name
}

output "repository_arn" {
  description = "ECRリポジトリのARN。"
  value       = aws_ecr_repository.this.arn
}

output "repository_url" {
  description = "コンテナイメージのpush先URL。"
  value       = aws_ecr_repository.this.repository_url
}
