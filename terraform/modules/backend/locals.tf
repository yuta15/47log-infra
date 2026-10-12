locals {
  lambdas      = var.lambdas
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

  public_routes = {
    for route_key, lambda_key in var.public_routes : route_key => {
      lambda_key    = lambda_key
      authorization = "NONE"
      scopes        = toset([])
    }
  }
  # CORS有効かつJWT認可付き$defaultの場合のみ、ルート直下も含めOPTIONSを明示する。
  preflight_keys = var.cors_configuration != null && try(local.default_routes["$default"].authorization == "JWT", false) ? toset([
    "OPTIONS /{proxy+}", "OPTIONS /"
  ]) : toset([])
  preflight_routes = {
    for key in local.preflight_keys : key => {
      lambda_key    = local.lambda_routes["$default"].lambda_key
      authorization = "NONE"
      scopes        = toset([])
    }
  }
  api_routes = merge(local.lambda_routes, local.public_routes, local.preflight_routes)
}
