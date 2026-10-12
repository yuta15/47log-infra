variable "project_name" {
  description = "S3バケット名とCloudFront関連リソース名に使用する名前。環境ごとに一意な名前を指定する。"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,58}[a-z0-9]$", var.project_name))
    error_message = "project_name はS3とCloudFrontの両方で使用するため、3〜60文字の小文字英数字・ハイフンとし、先頭と末尾は英数字にしてください。"
  }

  validation {
    condition = try(
      !anytrue([for prefix in ["xn--", "sthree-", "amzn-s3-demo-"] : startswith(var.project_name, prefix)]) &&
      !anytrue([for suffix in ["-s3alias", "--ol-s3", "--x-s3", "--table-s3", "-an"] : endswith(var.project_name, suffix)]),
      false
    )
    error_message = "project_name にS3の予約済み接頭辞・接尾辞は使用できません。"
  }
}

variable "tags" {
  description = "S3バケットとCloudFront Distributionに付与するタグ。"
  type        = map(string)
  default     = {}
}
