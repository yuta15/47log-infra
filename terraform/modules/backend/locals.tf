locals {
  lambdas      = var.enable_backend_modules ? var.lambdas : {}
  requires_jwt = anytrue([for lambda in values(var.lambdas) : lambda.authorization == "JWT"])

  # $defaultはパスベースのルート生成から分離し、1ルートだけ作成する。
  default_routes = merge({}, [for key, lambda in var.lambdas : {
    "$default" = { lambda_key = key, authorization = lambda.authorization, scopes = lambda.scopes }
  } if lambda.route_path == "$default"]...)
  path_routes = merge({}, [for key, lambda in var.lambdas : {
    for route_key in [
      "ANY ${lambda.route_path}", "ANY ${lambda.route_path == "/" ? "" : lambda.route_path}/{proxy+}"
    ] : route_key => { lambda_key = key, authorization = lambda.authorization, scopes = lambda.scopes }
  } if lambda.route_path != "$default"]...)
  lambda_routes = merge(local.default_routes, local.path_routes)

  auxiliary_target = var.auxiliary_lambda_target != null ? var.auxiliary_lambda_target : try(one(keys(var.lambdas)), null)
  # JWT認可付き$defaultを使う場合のみ、認可不要のOPTIONSを明示する。
  preflight_keys = try(local.default_routes["$default"].authorization == "JWT", false) ? toset(concat(
    ["OPTIONS /{proxy+}"], var.enable_root_preflight ? ["OPTIONS /"] : []
  )) : toset([])
  health_routes = var.enable_health_and_preflight_routes ? {
    "GET /health" = { lambda_key = local.auxiliary_target, authorization = "NONE", scopes = toset([]) }
  } : {}
  preflight_routes = {
    for key in local.preflight_keys : key => {
      lambda_key    = local.lambda_routes["$default"].lambda_key
      authorization = "NONE"
      scopes        = toset([])
    }
  }
  api_routes = merge(local.lambda_routes, local.health_routes, local.preflight_routes)
}
