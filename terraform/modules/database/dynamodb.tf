resource "aws_dynamodb_table" "this" {
  for_each = var.tables

  name         = each.key
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = each.value.hash_key
  range_key    = each.value.range_key
  tags         = var.tags

  dynamic "attribute" {
    for_each = each.value.attributes

    content {
      name = attribute.key
      type = attribute.value
    }
  }
}
