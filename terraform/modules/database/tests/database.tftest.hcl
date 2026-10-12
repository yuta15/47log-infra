mock_provider "aws" {}

run "multiple_tables" {
  command = apply
  variables {
    tags = {
      Project     = "47log"
      Environment = "test"
    }
    tables = {
      users = {
        hash_key   = "user_id"
        attributes = { user_id = "S" }
      }
      visits = {
        hash_key   = "user_id"
        range_key  = "visited_at"
        attributes = { user_id = "S", visited_at = "N" }
      }
    }
  }
  assert {
    condition = (
      toset(keys(aws_dynamodb_table.this)) == toset(["users", "visits"]) &&
      alltrue([for key, table in aws_dynamodb_table.this :
        table.name == key && table.billing_mode == "PAY_PER_REQUEST" &&
        table.tags == var.tags &&
        table.hash_key == var.tables[key].hash_key &&
        tomap({ for attribute in table.attribute : attribute.name => attribute.type }) == var.tables[key].attributes &&
        output.table_arns[key] == table.arn
      ]) &&
      aws_dynamodb_table.this["users"].range_key == null &&
      aws_dynamodb_table.this["visits"].range_key == "visited_at"
    )
    error_message = "tablesの指定に従いテーブルを作成し、共通タグ・キー・属性・ARN出力を維持する必要があります。"
  }
}

run "empty_tables" {
  command = plan
  variables { tables = {} }
  expect_failures = [var.tables]
}
