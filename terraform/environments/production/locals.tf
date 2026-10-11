locals {
  # 本番環境のテーブル定義。キーは実際のテーブル名。
  tables = {
    # 定義例:
    # "47log-production-logs" = {
    #   hash_key  = "user_id"
    #   range_key = "created_at"
    #   attributes = {
    #     user_id    = "S"
    #     created_at = "S"
    #   }
    # }
  }
}
