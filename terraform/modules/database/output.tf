output "table_arns" {
  description = "テーブル名をキー、DynamoDBテーブルのARNを値とするマップ。"
  value = {
    for name, table in aws_dynamodb_table.this : name => table.arn
  }
}
