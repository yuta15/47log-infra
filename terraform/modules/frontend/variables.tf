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

variable "development_allowed_ip_cidrs" {
  description = "Environmentタグがdev/developmentの場合だけ許可する送信元IP。IPv4は/32、IPv6は/128で指定する。productionでは使用しない。"
  type        = set(string)
  default     = []
  nullable    = false

  validation {
    condition = alltrue([
      for cidr in var.development_allowed_ip_cidrs :
      can(cidrhost(cidr, 0)) && endswith(cidr, strcontains(cidr, ":") ? "/128" : "/32")
    ])
    error_message = "development_allowed_ip_cidrsにはIPv4の/32またはIPv6の/128を指定してください。"
  }
}

variable "tags" {
  description = "S3バケットとCloudFront Distributionに付与するタグ。"
  type        = map(string)
  default     = {}
}
