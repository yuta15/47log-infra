mock_provider "aws" {
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::123456789012:role/test-lambda" }
  }
  mock_resource "aws_cloudwatch_log_group" {
    defaults = { arn = "arn:aws:logs:ap-northeast-1:123456789012:log-group:/aws/lambda/test" }
  }
  mock_resource "aws_lambda_function" {
    defaults = { arn = "arn:aws:lambda:ap-northeast-1:123456789012:function:test" }
  }
  mock_resource "aws_apigatewayv2_api" {
    defaults = {
      execution_arn = "arn:aws:execute-api:ap-northeast-1:123456789012:test-api"
      api_endpoint  = "https://test-api.execute-api.ap-northeast-1.amazonaws.com"
    }
  }
}

variables {
  name               = "47log-test-api"
  cors_configuration = { allow_origins = ["https://app.example.com"] }
  lambdas = {
    "47log-test-api" = {
      route_path = "$default"
      image_uri  = "123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/47log-api:bootstrap"
    }
  }
  jwt_authorizer = {
    issuer   = "https://cognito-idp.ap-northeast-1.amazonaws.com/ap-northeast-1_example"
    audience = ["47log-api"]
  }
}

run "default_only" {
  command = apply

  assert {
    condition = (
      length(aws_lambda_function.this) == 1 && length(aws_iam_role.this) == 1 &&
      length(aws_cloudwatch_log_group.this) == 1 && length(aws_iam_role_policy.logs) == 1 &&
      length(aws_iam_role_policy.dynamodb) == 0 && length(aws_apigatewayv2_integration.this) == 1 &&
      toset(keys(aws_apigatewayv2_route.this)) == toset(["$default", "OPTIONS /", "OPTIONS /{proxy+}"]) &&
      aws_apigatewayv2_route.this["$default"].authorization_type == "JWT" &&
      aws_apigatewayv2_route.this["$default"].authorizer_id == aws_apigatewayv2_authorizer.this[0].id &&
      aws_apigatewayv2_stage.this.name == "$default" && aws_apigatewayv2_stage.this.auto_deploy &&
      aws_apigatewayv2_api.this.cors_configuration[0].allow_origins == var.cors_configuration.allow_origins &&
      length(aws_apigatewayv2_stage.this.default_route_settings) == 0 &&
      aws_lambda_function.this["47log-test-api"].function_name == "${var.name}-47log-test-api" &&
      aws_lambda_function.this["47log-test-api"].package_type == "Image" &&
      aws_lambda_function.this["47log-test-api"].image_uri == var.lambdas["47log-test-api"].image_uri &&
      output.lambda_function_names["47log-test-api"] == aws_lambda_function.this["47log-test-api"].function_name &&
      output.lambda_function_arns["47log-test-api"] == aws_lambda_function.this["47log-test-api"].arn &&
      output.lambda_execution_role_arns["47log-test-api"] == aws_iam_role.this["47log-test-api"].arn &&
      output.api_endpoint == aws_apigatewayv2_api.this.api_endpoint && output.api_id == aws_apigatewayv2_api.this.id
    )
    error_message = "default用Lambdaを1つ作成し、JWT認可付きdefaultと認可不要のプリフライトだけを作成する必要があります。"
  }
}

run "default_with_health_and_root_preflight" {
  command = apply
  variables {
    public_routes      = { "GET /health" = "47log-test-api" }
    cors_configuration = { allow_origins = ["https://app.example.com"] }

  }

  assert {
    condition = (
      length(aws_lambda_function.this) == 1 && length(aws_apigatewayv2_integration.this) == 1 &&
      toset(keys(aws_apigatewayv2_route.this)) == toset(["$default", "GET /health", "OPTIONS /", "OPTIONS /{proxy+}"]) &&
      alltrue([for key in ["GET /health", "OPTIONS /", "OPTIONS /{proxy+}"] :
        aws_apigatewayv2_route.this[key].authorization_type == "NONE" &&
        aws_apigatewayv2_route.this[key].authorizer_id == null &&
        aws_apigatewayv2_route.this[key].target == aws_apigatewayv2_route.this["$default"].target
      ])
    )
    error_message = "追加ルートは認可不要で通常ルートのLambdaを共有し、Lambdaを増やさない必要があります。"
  }
}

run "multiple_routes_and_lambda_settings" {
  command = apply
  variables {
    lambdas = {
      "47log-test-users" = {
        route_path   = "/users"
        image_uri    = "123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/users:bootstrap"
        scopes       = ["users:read"]
        architecture = "arm64"
        memory_size  = 512
        timeout      = 10

        environment_variables = { LOG_LEVEL = "INFO" }
        table_arns            = { users = "arn:aws:dynamodb:ap-northeast-1:123456789012:table/users" }
      }
      "47log-test-webhook" = {
        route_path    = "/webhook"
        image_uri     = "123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/webhook:bootstrap"
        authorization = "NONE"
      }
    }
    public_routes = { "GET /health" = "47log-test-users" }
    cors_configuration = {
      allow_origins     = ["https://app.example.com"]
      allow_methods     = ["GET", "POST", "OPTIONS"]
      allow_headers     = ["authorization", "content-type", "x-request-id"]
      expose_headers    = ["x-request-id"]
      allow_credentials = true
      max_age           = 3600
    }
    throttling = { rate_limit = 100, burst_limit = 200 }
  }

  assert {
    condition = (
      toset(keys(aws_lambda_function.this)) == toset(keys(var.lambdas)) &&
      length(aws_apigatewayv2_integration.this) == 2 && !contains(keys(aws_apigatewayv2_route.this), "$default") &&
      alltrue([for key, function in aws_lambda_function.this :
        function.function_name == "${var.name}-${key}" && function.image_uri == var.lambdas[key].image_uri &&
        function.role == aws_iam_role.this[key].arn &&
        aws_apigatewayv2_integration.this[key].integration_uri == function.arn &&
        aws_apigatewayv2_integration.this[key].payload_format_version == "2.0" &&
        aws_apigatewayv2_integration.this[key].integration_type == "AWS_PROXY" &&
        aws_apigatewayv2_integration.this[key].integration_method == "POST" &&
        aws_apigatewayv2_integration.this[key].timeout_milliseconds == 30000 &&
        aws_lambda_permission.this[key].function_name == function.arn &&
        aws_lambda_permission.this[key].principal == "apigateway.amazonaws.com" &&
        aws_lambda_permission.this[key].source_arn == "${aws_apigatewayv2_api.this.execution_arn}/$default/*"
      ]) &&
      aws_apigatewayv2_route.this["ANY /users"].target == "integrations/${aws_apigatewayv2_integration.this["47log-test-users"].id}" &&
      aws_apigatewayv2_route.this["ANY /users"].authorizer_id == aws_apigatewayv2_authorizer.this[0].id &&
      aws_apigatewayv2_route.this["ANY /users"].authorization_scopes == toset(["users:read"]) &&
      length(aws_apigatewayv2_route.this) == 5 &&
      aws_apigatewayv2_route.this["ANY /users/{proxy+}"].target == aws_apigatewayv2_route.this["ANY /users"].target &&
      aws_apigatewayv2_route.this["ANY /users/{proxy+}"].authorizer_id == aws_apigatewayv2_authorizer.this[0].id &&
      aws_apigatewayv2_route.this["ANY /users/{proxy+}"].authorization_scopes == toset(["users:read"]) &&
      aws_apigatewayv2_route.this["ANY /webhook"].target == "integrations/${aws_apigatewayv2_integration.this["47log-test-webhook"].id}" &&
      alltrue([for key in ["GET /health", "ANY /webhook", "ANY /webhook/{proxy+}"] : aws_apigatewayv2_route.this[key].authorization_type == "NONE" && aws_apigatewayv2_route.this[key].authorizer_id == null]) &&
      aws_apigatewayv2_route.this["GET /health"].target == aws_apigatewayv2_route.this["ANY /users"].target &&
      toset(keys(aws_apigatewayv2_route.this)) == toset(["ANY /users", "ANY /users/{proxy+}", "GET /health", "ANY /webhook", "ANY /webhook/{proxy+}"]) &&
      aws_apigatewayv2_route.this["ANY /webhook/{proxy+}"].target == aws_apigatewayv2_route.this["ANY /webhook"].target
    )
    error_message = "通常ルートごとにLambdaを作成して認可設定を反映し、追加ルートを選択したLambdaへ接続する必要があります。"
  }

  assert {
    condition = (
      aws_lambda_function.this["47log-test-users"].architectures == tolist(["arm64"]) &&
      aws_lambda_function.this["47log-test-users"].memory_size == 512 && aws_lambda_function.this["47log-test-users"].timeout == 10 &&
      aws_lambda_function.this["47log-test-users"].environment[0].variables["LOG_LEVEL"] == "INFO" &&
      aws_apigatewayv2_integration.this["47log-test-users"].timeout_milliseconds == 30000 &&
      toset(keys(aws_iam_role_policy.dynamodb)) == toset(["47log-test-users"]) &&
      toset(jsondecode(aws_iam_role_policy.dynamodb["47log-test-users"].policy).Statement[0].Resource) == toset(values(var.lambdas["47log-test-users"].table_arns)) &&
      toset(jsondecode(aws_iam_role_policy.dynamodb["47log-test-users"].policy).Statement[1].Resource) == toset([
        var.lambdas["47log-test-users"].table_arns["users"], "${var.lambdas["47log-test-users"].table_arns["users"]}/index/*"
      ]) &&
      alltrue([for key, policy in aws_iam_role_policy.logs :
        jsondecode(policy.policy).Statement[0].Resource == "${aws_cloudwatch_log_group.this[key].arn}:*" &&
        aws_cloudwatch_log_group.this[key].retention_in_days == 30 &&
        jsondecode(aws_iam_role.this[key].assume_role_policy).Statement[0].Principal.Service == "lambda.amazonaws.com"
      ]) &&
      aws_apigatewayv2_stage.this.default_route_settings[0].throttling_rate_limit == 100 &&
      aws_apigatewayv2_stage.this.default_route_settings[0].throttling_burst_limit == 200 &&
      aws_apigatewayv2_api.this.cors_configuration[0].allow_origins == var.cors_configuration.allow_origins &&
      aws_apigatewayv2_api.this.cors_configuration[0].allow_methods == var.cors_configuration.allow_methods &&
      aws_apigatewayv2_api.this.cors_configuration[0].allow_headers == var.cors_configuration.allow_headers &&
      aws_apigatewayv2_api.this.cors_configuration[0].expose_headers == var.cors_configuration.expose_headers &&
      aws_apigatewayv2_api.this.cors_configuration[0].allow_credentials &&
      aws_apigatewayv2_api.this.cors_configuration[0].max_age == 3600
    )
    error_message = "Lambdaごとの設定と最小権限、CORS、スロットリングを反映する必要があります。"
  }
}

run "without_jwt" {
  command = apply
  variables {
    lambdas = {
      "47log-test-api" = {
        route_path    = "$default"
        image_uri     = "123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/47log-api:bootstrap"
        authorization = "NONE"
      }
    }
    jwt_authorizer     = null
    cors_configuration = null

  }
  assert {
    condition = (
      length(aws_apigatewayv2_authorizer.this) == 0 &&
      aws_apigatewayv2_route.this["$default"].authorization_type == "NONE" &&
      aws_apigatewayv2_route.this["$default"].authorizer_id == null &&
      toset(keys(aws_apigatewayv2_route.this)) == toset(["$default"])
    )
    error_message = "JWTを使わない場合はauthorizerと明示的なOPTIONS、healthを自動作成しないする必要があります。"
  }
}

run "environment_names_and_access_logs" {
  command = apply
  variables {
    name = "47log-production"
    tags = { Environment = "production" }
  }
  assert {
    condition = (
      aws_lambda_function.this["47log-test-api"].function_name == "47log-production-47log-test-api" &&
      aws_cloudwatch_log_group.this["47log-test-api"].name == "/aws/lambda/47log-production-47log-test-api" &&
      startswith(aws_iam_role.this["47log-test-api"].name_prefix, "47log-production-") &&
      aws_cloudwatch_log_group.api_gateway.name == "/aws/apigateway/47log-production" &&
      aws_cloudwatch_log_group.api_gateway.retention_in_days == 14 &&
      aws_cloudwatch_log_group.api_gateway.tags == var.tags &&
      aws_apigatewayv2_stage.this.access_log_settings[0].destination_arn == aws_cloudwatch_log_group.api_gateway.arn &&
      jsondecode(aws_apigatewayv2_stage.this.access_log_settings[0].format) == {
        requestId         = "$context.requestId"
        routeKey          = "$context.routeKey"
        status            = "$context.status"
        responseLatency   = "$context.responseLatency"
        integrationStatus = "$context.integrationStatus"
        requestTime       = "$context.requestTime"
        httpMethod        = "$context.httpMethod"
        responseLength    = "$context.responseLength"
      }
    )
    error_message = "環境名を各リソース名に含め、機密情報を含まないAPIアクセスログをLambdaと分離して14日保持する必要があります。"
  }
}

run "missing_jwt" {
  command = plan
  variables { jwt_authorizer = null }
  expect_failures = [var.jwt_authorizer]
}

run "empty_lambdas" {
  command = plan
  variables { lambdas = {} }
  expect_failures = [var.lambdas]
}

run "missing_public_route_target" {
  command = plan
  variables { public_routes = { "GET /health" = "missing" } }
  expect_failures = [var.public_routes]
}

run "invalid_public_route_key" {
  command = plan
  variables { public_routes = { "/health" = "47log-test-api" } }
  expect_failures = [var.public_routes]
}

run "health_path_is_not_reserved" {
  command = apply
  variables {
    lambdas        = { health = { route_path = "/health", image_uri = "example/health:bootstrap", authorization = "NONE" } }
    jwt_authorizer = null
  }
  assert {
    condition     = toset(keys(aws_apigatewayv2_route.this)) == toset(["ANY /health", "ANY /health/{proxy+}"])
    error_message = "healthは予約せず、Lambdaの通常ルートとして定義できる必要があります。"
  }
}

run "invalid_proxy_path" {
  command = plan
  variables {

    lambdas = { "options" = {
    route_path = "/user/{proxy+}", image_uri = "example/options:bootstrap" } }
  }
  expect_failures = [var.lambdas]
}

run "duplicate_route_path" {
  command = plan
  variables {
    lambdas = {
      "first-lambda"  = { route_path = "/users", image_uri = "example/users:bootstrap" }
      "second-lambda" = { route_path = "/users", image_uri = "example/users:bootstrap" }
    }
  }
  expect_failures = [var.lambdas]
}

run "invalid_lambda_settings" {
  command = plan
  variables {
    lambdas = { "api" = {
    route_path = "$default", image_uri = "example/api:bootstrap", memory_size = 127 } }
  }
  expect_failures = [var.lambdas]
}

run "invalid_route_path" {
  command = plan
  variables { lambdas = { "api" = {
  route_path = "users", image_uri = "example/api:bootstrap" } } }
  expect_failures = [var.lambdas]
}

run "invalid_credentialed_cors" {
  command = plan
  variables { cors_configuration = { allow_origins = ["*"], allow_credentials = true } }
  expect_failures = [var.cors_configuration]
}

run "invalid_throttling" {
  command = plan
  variables { throttling = { rate_limit = -1, burst_limit = 1.5 } }
  expect_failures = [var.throttling]
}

run "user_lambda_without_auxiliary_routes" {
  command = apply
  variables {
    lambdas = {
      "user-lambda" = { route_path = "/user", image_uri = "example/user:bootstrap" }
    }
  }
  assert {
    condition = (
      length(aws_lambda_function.this) == 1 && aws_lambda_function.this["user-lambda"].function_name == "${var.name}-user-lambda" &&
      length(aws_apigatewayv2_integration.this) == 1 && length(aws_apigatewayv2_route.this) == 2 &&
      toset(keys(aws_apigatewayv2_route.this)) == toset(["ANY /user", "ANY /user/{proxy+}"]) &&
      alltrue([for route in aws_apigatewayv2_route.this :
        route.target == "integrations/${aws_apigatewayv2_integration.this["user-lambda"].id}" &&
        route.authorization_type == "JWT"
      ])
    )
    error_message = "user-lambdaの指定から完全一致と配下の2ルートだけを生成し、同じLambdaへ統合する必要があります。"
  }
}

run "root_path" {
  command = apply
  variables {
    lambdas = {
      "root-lambda" = { route_path = "/", image_uri = "example/root:bootstrap", authorization = "NONE" }
    }
    jwt_authorizer = null
  }
  assert {
    condition = (
      toset(keys(aws_apigatewayv2_route.this)) == toset(["ANY /", "ANY /{proxy+}"]) &&
      length(aws_lambda_function.this) == 1 && length(aws_apigatewayv2_authorizer.this) == 0
    )
    error_message = "ルート直下のパスでも二重スラッシュなしでルートを生成する必要があります。"
  }
}

run "cognito_default_preflight_without_health" {
  command = apply
  variables {
    cors_configuration = { allow_origins = ["https://app.example.com"] }
  }
  assert {
    condition = (
      toset(keys(aws_apigatewayv2_route.this)) == toset(["$default", "OPTIONS /", "OPTIONS /{proxy+}"]) &&
      aws_apigatewayv2_route.this["$default"].authorization_type == "JWT" &&
      aws_apigatewayv2_route.this["OPTIONS /{proxy+}"].authorization_type == "NONE" &&
      aws_apigatewayv2_route.this["OPTIONS /{proxy+}"].authorizer_id == null &&
      aws_apigatewayv2_route.this["OPTIONS /{proxy+}"].target == aws_apigatewayv2_route.this["$default"].target &&
      aws_apigatewayv2_authorizer.this[0].jwt_configuration[0].issuer == var.jwt_authorizer.issuer &&
      aws_apigatewayv2_authorizer.this[0].jwt_configuration[0].audience == var.jwt_authorizer.audience
    )
    error_message = "Cognito認可付きdefaultとCORSを使う場合はルート直下を含む認可不要OPTIONSを追加する必要があります。"
  }
}

run "users_and_visits" {
  command = apply
  variables {
    lambdas = {
      users  = { route_path = "/users", image_uri = "example/users:bootstrap" }
      visits = { route_path = "/visits", image_uri = "example/visits:bootstrap" }
    }
    cors_configuration = { allow_origins = ["https://app.example.com"] }
  }
  assert {
    condition = (
      aws_apigatewayv2_api.this.protocol_type == "HTTP" && length(aws_lambda_function.this) == 2 &&
      length(aws_apigatewayv2_integration.this) == 2 && length(aws_lambda_permission.this) == 2 &&
      toset(keys(aws_apigatewayv2_route.this)) == toset(["ANY /users", "ANY /users/{proxy+}", "ANY /visits", "ANY /visits/{proxy+}"]) &&
      aws_apigatewayv2_route.this["ANY /users"].target == "integrations/${aws_apigatewayv2_integration.this["users"].id}" &&
      aws_apigatewayv2_route.this["ANY /users/{proxy+}"].target == aws_apigatewayv2_route.this["ANY /users"].target &&
      aws_apigatewayv2_route.this["ANY /visits"].target == "integrations/${aws_apigatewayv2_integration.this["visits"].id}" &&
      aws_apigatewayv2_route.this["ANY /visits/{proxy+}"].target == aws_apigatewayv2_route.this["ANY /visits"].target &&
      alltrue([for route in aws_apigatewayv2_route.this : route.authorization_type == "JWT"])
    )
    error_message = "usersとvisitsの各Lambdaに2つのANYルートを生成し、CORS設定だけではOPTIONSを明示しない必要があります。"
  }
}

run "explicit_public_health_lambda" {
  command = apply
  variables {
    lambdas = {
      users  = { route_path = "/users", image_uri = "example/users:bootstrap" }
      health = { route_path = "/health", image_uri = "example/health:bootstrap", authorization = "NONE" }
    }
  }
  assert {
    condition = (
      aws_apigatewayv2_route.this["ANY /health"].authorization_type == "NONE" &&
      aws_apigatewayv2_route.this["ANY /health/{proxy+}"].authorization_type == "NONE" &&
      aws_apigatewayv2_route.this["ANY /health"].authorizer_id == null &&
      aws_apigatewayv2_route.this["ANY /health"].target == "integrations/${aws_apigatewayv2_integration.this["health"].id}" &&
      aws_apigatewayv2_route.this["ANY /users"].authorization_type == "JWT"
    )
    error_message = "health用LambdaにNONEを明示し、通常LambdaのJWT認可を維持できる必要があります。"
  }
}

run "default_with_users_and_visits" {
  command = apply
  variables {
    lambdas = {
      default = { route_path = "$default", image_uri = "example/default:bootstrap" }
      users   = { route_path = "/users", image_uri = "example/users:bootstrap" }
      visits  = { route_path = "/visits", image_uri = "example/visits:bootstrap" }
    }
  }
  assert {
    condition = (
      length(aws_lambda_function.this) == 3 && length(aws_apigatewayv2_integration.this) == 3 &&
      toset(keys(aws_apigatewayv2_route.this)) == toset([
        "$default", "OPTIONS /", "OPTIONS /{proxy+}", "ANY /users", "ANY /users/{proxy+}", "ANY /visits", "ANY /visits/{proxy+}"
      ]) &&
      aws_apigatewayv2_route.this["$default"].target == "integrations/${aws_apigatewayv2_integration.this["default"].id}" &&
      aws_apigatewayv2_route.this["$default"].authorization_type == "JWT" &&
      aws_apigatewayv2_route.this["$default"].authorizer_id == aws_apigatewayv2_authorizer.this[0].id &&
      aws_apigatewayv2_route.this["OPTIONS /{proxy+}"].target == aws_apigatewayv2_route.this["$default"].target &&
      aws_apigatewayv2_route.this["OPTIONS /{proxy+}"].authorization_type == "NONE" &&
      aws_apigatewayv2_route.this["OPTIONS /{proxy+}"].authorizer_id == null &&
      aws_apigatewayv2_route.this["ANY /users"].target == "integrations/${aws_apigatewayv2_integration.this["users"].id}" &&
      aws_apigatewayv2_route.this["ANY /users/{proxy+}"].target == aws_apigatewayv2_route.this["ANY /users"].target &&
      aws_apigatewayv2_route.this["ANY /visits"].target == "integrations/${aws_apigatewayv2_integration.this["visits"].id}" &&
      aws_apigatewayv2_route.this["ANY /visits/{proxy+}"].target == aws_apigatewayv2_route.this["ANY /visits"].target
    )
    error_message = "defaultと通常パスを混在させても、余分なANY /{proxy+}を生成せず各Lambdaへ接続する必要があります。"
  }
}

run "duplicate_default" {
  command = plan
  variables {
    lambdas = {
      first  = { route_path = "$default", image_uri = "example/first:bootstrap" }
      second = { route_path = "$default", image_uri = "example/second:bootstrap" }
    }
  }
  expect_failures = [var.lambdas]
}

run "jwt_default_without_cors" {
  command = apply
  variables { cors_configuration = null }
  assert {
    condition = (
      toset(keys(aws_apigatewayv2_route.this)) == toset(["$default"]) &&
      aws_apigatewayv2_route.this["$default"].authorization_type == "JWT"
    )
    error_message = "CORSを無効にしたJWT付きdefaultはOPTIONSを生成しない必要があります。"
  }
}

run "public_default_with_private_users" {
  command = apply
  variables {
    lambdas = {
      default = { route_path = "$default", image_uri = "example/default:bootstrap", authorization = "NONE" }
      users   = { route_path = "/users", image_uri = "example/users:bootstrap" }
    }

  }
  assert {
    condition = (
      toset(keys(aws_apigatewayv2_route.this)) == toset(["$default", "ANY /users", "ANY /users/{proxy+}"]) &&
      aws_apigatewayv2_route.this["$default"].authorization_type == "NONE" &&
      aws_apigatewayv2_route.this["ANY /users"].authorization_type == "JWT"
    )
    error_message = "defaultが認可不要なら、他のJWTルートがあってもOPTIONSを追加しない必要があります。"
  }
}

run "invalid_environment_name" {
  command = plan
  variables { name = "invalid/name" }
  expect_failures = [var.name]
}

run "lambda_name_too_long" {
  command = plan
  variables { name = "abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghij" }
  expect_failures = [var.lambdas]
}

run "invalid_lambda_key" {
  command = plan
  variables { lambdas = { "invalid/key" = { route_path = "/users", image_uri = "example/users:bootstrap" } } }
  expect_failures = [var.lambdas]
}

run "invalid_authorization" {
  command = plan
  variables { lambdas = { api = { route_path = "$default", image_uri = "example/api:bootstrap", authorization = "IAM" } } }
  expect_failures = [var.lambdas]
}

run "scopes_without_jwt" {
  command = plan
  variables { lambdas = { api = { route_path = "$default", image_uri = "example/api:bootstrap", authorization = "NONE", scopes = ["users:read"] } } }
  expect_failures = [var.lambdas]
}

run "invalid_timeout" {
  command = plan
  variables { lambdas = { api = { route_path = "$default", image_uri = "example/api:bootstrap", timeout = 901 } } }
  expect_failures = [var.lambdas]
}

run "invalid_table_arn" {
  command = plan
  variables { lambdas = { api = { route_path = "$default", image_uri = "example/api:bootstrap", table_arns = { users = "arn:aws:s3:::users" } } } }
  expect_failures = [var.lambdas]
}

run "invalid_jwt_settings" {
  command = plan
  variables { jwt_authorizer = { issuer = "http://example.com", audience = [] } }
  expect_failures = [var.jwt_authorizer]
}

run "invalid_cors_methods_and_age" {
  command = plan
  variables { cors_configuration = { allow_origins = ["https://example.com"], allow_methods = ["INVALID"], max_age = 86401 } }
  expect_failures = [var.cors_configuration]
}
