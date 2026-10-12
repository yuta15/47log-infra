variable "bucket_name" {
  description = "配信ファイルを保存するS3バケット名。環境ごとに一意な名前を指定する。"
  type        = string

  validation {
    condition     = try(length(trimspace(var.bucket_name)) > 0, false)
    error_message = "bucket_name を指定してください。"
  }
}

variable "tags" {
  description = "S3バケットとCloudFront Distributionに付与するタグ。"
  type        = map(string)
  default     = {}
}
