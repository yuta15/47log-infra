variable "tables" {
  description = "テーブル名をキーとするDynamoDBテーブル定義。attributesには主キーに使う属性のみを指定する。"
  type = map(object({
    hash_key   = string
    range_key  = optional(string)
    attributes = map(string)
  }))

  validation {
    condition     = length(var.tables) > 0
    error_message = "tables に少なくとも1つのテーブルを定義してください。"
  }
}
