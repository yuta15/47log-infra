variable "repository_name" {
  description = "ECRリポジトリ名。"
  type        = string
}

variable "tags" {
  description = "ECRリポジトリに付与するタグ。"
  type        = map(string)
  default     = {}
}
