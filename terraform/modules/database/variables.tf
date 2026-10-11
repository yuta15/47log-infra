variable "enable_database_modules" {
  description = "databaseモジュールを有効化するかどうか"
  type        = bool
}

variable "tables" {
  description = "テーブル名をキーとするDynamoDBテーブル定義。attributesには主キーに使う属性のみを指定する。"
  type = map(object({
    hash_key   = string
    range_key  = optional(string)
    attributes = map(string)
  }))

  validation {
    condition     = !var.enable_database_modules || length(var.tables) > 0
    error_message = "enable_database_modules が true の場合、tables に少なくとも1つのテーブルを定義してください。"
  }
}
