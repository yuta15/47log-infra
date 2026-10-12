resource "aws_apigatewayv2_api" "this" {
  name          = var.project_name
  protocol_type = "HTTP"
  tags          = var.tags

  dynamic "cors_configuration" {
    for_each = var.cors_configuration == null ? [] : [var.cors_configuration]

    content {
      allow_origins     = cors_configuration.value.allow_origins
      allow_methods     = cors_configuration.value.allow_methods
      allow_headers     = cors_configuration.value.allow_headers
      expose_headers    = cors_configuration.value.expose_headers
      allow_credentials = cors_configuration.value.allow_credentials
      max_age           = cors_configuration.value.max_age
    }
  }
}

resource "aws_apigatewayv2_integration" "this" {
  for_each = local.lambdas

  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_method     = "POST"
  integration_uri        = aws_lambda_function.this[each.key].arn
  timeout_milliseconds   = 30000
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_authorizer" "this" {
  count = local.requires_jwt ? 1 : 0

  api_id           = aws_apigatewayv2_api.this.id
  name             = "jwt"
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]

  jwt_configuration {
    issuer   = var.jwt_authorizer.issuer
    audience = var.jwt_authorizer.audience
  }
}

resource "aws_apigatewayv2_route" "this" {
  for_each = local.api_routes

  api_id               = aws_apigatewayv2_api.this.id
  route_key            = each.key
  target               = "integrations/${aws_apigatewayv2_integration.this[each.value.lambda_key].id}"
  authorization_type   = each.value.authorization
  authorizer_id        = each.value.authorization == "JWT" ? aws_apigatewayv2_authorizer.this[0].id : null
  authorization_scopes = each.value.authorization == "JWT" ? each.value.scopes : null
}

resource "aws_apigatewayv2_stage" "this" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = "$default"
  auto_deploy = true
  tags        = var.tags

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    # ヘッダー、JWT claims、リクエスト本文は記録しない。
    format = jsonencode({
      requestId         = "$context.requestId"
      routeKey          = "$context.routeKey"
      status            = "$context.status"
      responseLatency   = "$context.responseLatency"
      integrationStatus = "$context.integrationStatus"
      requestTime       = "$context.requestTime"
      httpMethod        = "$context.httpMethod"
      responseLength    = "$context.responseLength"
    })
  }

  dynamic "default_route_settings" {
    for_each = var.throttling == null ? [] : [var.throttling]

    content {
      throttling_rate_limit  = default_route_settings.value.rate_limit
      throttling_burst_limit = default_route_settings.value.burst_limit
    }
  }
}

resource "aws_lambda_permission" "this" {
  for_each = local.lambdas

  # 同じLambdaを複数の統合・APIで使う場合もstatement IDを重複させない。
  statement_id_prefix = "AllowAPIGatewayInvoke-"
  action              = "lambda:InvokeFunction"
  function_name       = aws_lambda_function.this[each.key].arn
  principal           = "apigateway.amazonaws.com"
  source_arn          = "${aws_apigatewayv2_api.this.execution_arn}/$default/*"
}

resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.project_name}"
  retention_in_days = 14
  tags              = var.tags
}
