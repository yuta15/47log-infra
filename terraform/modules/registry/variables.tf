variable "repository_name" {
  description = "ECRリポジトリ名。"
  type        = string
}

variable "force_delete" {
  description = "イメージが残っているECRリポジトリの削除を許可する。"
  type        = bool
  default     = false
}

variable "tags" {
  description = "ECRリポジトリに付与するタグ。"
  type        = map(string)
  default     = {}
}
