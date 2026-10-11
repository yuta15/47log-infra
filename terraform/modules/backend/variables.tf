variable "enable_backend_modules" {
  description = "backendモジュールを有効化するかどうか。"
  type        = bool
  default     = true
}

variable "name" {
  description = "HTTP API名。有効時は必須。"
  type        = string
  default     = null

  validation {
    condition     = !var.enable_backend_modules || try(length(trimspace(var.name)) > 0, false)
    error_message = "有効時はnameを指定してください。"
  }
}

variable "lambdas" {
  description = "Lambda関数名をキーとする設定。route_pathからANYの完全一致と配下ルートを自動作成する。"
  type = map(object({
    route_path            = string
    image_uri             = string
    authorization         = optional(string, "JWT")
    scopes                = optional(set(string), [])
    architecture          = optional(string, "x86_64")
    memory_size           = optional(number, 256)
    timeout               = optional(number, 30)
    timeout_milliseconds  = optional(number, 30000)
    environment_variables = optional(map(string), {})
    table_arns            = optional(map(string), {})
  }))
  default  = {}
  nullable = false

  validation {
    condition     = !var.enable_backend_modules || length(var.lambdas) > 0
    error_message = "有効時はlambdasを1つ以上指定してください。route_path=$defaultだけの構成も可能です。"
  }

  validation {
    condition = alltrue([for lambda in values(var.lambdas) :
      lambda.route_path == "$default" || can(regex("^/([A-Za-z0-9._~-]+(/[A-Za-z0-9._~-]+)*)?$", lambda.route_path))
    ]) && length(distinct([for lambda in values(var.lambdas) : lambda.route_path])) == length(var.lambdas)
    error_message = "route_pathには一意な$defaultまたは/userのような固定パスを指定してください。/以外の末尾スラッシュやパスパラメータは指定できません。"
  }

  validation {
    condition = alltrue([for route in values(var.lambdas) :
      contains(["JWT", "NONE"], route.authorization) && (route.authorization == "JWT" || length(route.scopes) == 0)
    ])
    error_message = "authorizationはJWTまたはNONEとし、scopesはJWTルートにのみ指定してください。"
  }

  validation {
    condition = alltrue([for key, lambda in var.lambdas :
      can(regex("^[A-Za-z0-9_-]{1,64}$", key)) && try(length(trimspace(lambda.image_uri)) > 0, false)
    ])
    error_message = "lambdasのキーには1〜64文字の英数字・ハイフン・アンダースコアの関数名を指定し、image_uriを空にしないでください。"
  }

  validation {
    condition = alltrue([for route in values(var.lambdas) :
      contains(["x86_64", "arm64"], route.architecture) &&
      route.memory_size >= 128 && route.memory_size <= 10240 && floor(route.memory_size) == route.memory_size &&
      route.timeout >= 1 && route.timeout <= 900 && floor(route.timeout) == route.timeout &&
      route.timeout_milliseconds >= 50 && route.timeout_milliseconds <= 30000 && floor(route.timeout_milliseconds) == route.timeout_milliseconds
    ])
    error_message = "architecture、memory_size（128〜10240整数）、timeout（1〜900整数）、timeout_milliseconds（50〜30000整数）を確認してください。"
  }

  validation {
    condition = alltrue(flatten([for route in values(var.lambdas) : [for arn in values(route.table_arns) :
      can(regex("^arn:[^:]+:dynamodb:[^:]+:[0-9]{12}:table/[^/]+$", arn))
    ]]))
    error_message = "table_arnsにはDynamoDBテーブルARNを指定してください。"
  }

  validation {
    condition = !var.enable_health_and_preflight_routes || alltrue([for lambda in values(var.lambdas) :
      lambda.route_path != "/health"
    ])
    error_message = "health/preflight自動追加時は予約済みの/healthをroute_pathに指定しないでください。"
  }
}

variable "enable_health_and_preflight_routes" {
  description = "認可不要のGET /healthを追加する。JWT認可付き$defaultへのOPTIONSはこのフラグに関係なく自動追加する。"
  type        = bool
  default     = false
}

variable "enable_root_preflight" {
  description = "JWT認可付き$defaultがある場合、ルート直下のプリフライト用OPTIONS /も追加する。"
  type        = bool
  default     = false
}

variable "auxiliary_lambda_target" {
  description = "healthの投げ先となるLambda名。Lambdaが1つなら省略可能。"
  type        = string
  default     = null

  validation {
    condition = !var.enable_backend_modules || !var.enable_health_and_preflight_routes || (
      var.auxiliary_lambda_target == null ? length(var.lambdas) == 1 : contains(keys(var.lambdas), var.auxiliary_lambda_target)
    )
    error_message = "health追加時にLambdaが複数ある場合は、auxiliary_lambda_targetにlambdasのキーを指定してください。"
  }
}

variable "jwt_authorizer" {
  description = "Cognito User PoolのissuerとアプリクライアントID（audience）。JWTルートがある場合は必須。"
  type = object({
    issuer   = string
    audience = set(string)
  })
  default = null

  validation {
    condition     = !var.enable_backend_modules || !anytrue([for route in values(var.lambdas) : route.authorization == "JWT"]) || var.jwt_authorizer != null
    error_message = "JWT認可のルートがある場合はjwt_authorizerを指定してください。"
  }

  validation {
    condition = var.jwt_authorizer == null ? true : try(
      startswith(var.jwt_authorizer.issuer, "https://") && length(var.jwt_authorizer.audience) > 0 &&
      alltrue([for audience in var.jwt_authorizer.audience : length(trimspace(audience)) > 0]), false
    )
    error_message = "jwt_authorizerにはHTTPSのissuerと空でないaudienceを指定してください。"
  }
}

variable "cors_configuration" {
  description = "HTTP APIのCORS設定。JWT認可付き$defaultを使う場合は必須。それ以外はnullでCORS処理を無効にできる。"
  type = object({
    allow_origins     = set(string)
    allow_methods     = optional(set(string), ["GET", "HEAD", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"])
    allow_headers     = optional(set(string), ["authorization", "content-type"])
    expose_headers    = optional(set(string), [])
    allow_credentials = optional(bool, false)
    max_age           = optional(number, 0)
  })
  default = null

  validation {
    condition = !var.enable_backend_modules || !anytrue([
      for lambda in values(var.lambdas) : lambda.route_path == "$default" && lambda.authorization == "JWT"
    ]) || var.cors_configuration != null
    error_message = "JWT認可付き$defaultのプリフライトをAPI Gatewayで処理するため、cors_configurationを指定してください。"
  }

  validation {
    condition = var.cors_configuration == null ? true : (
      length(var.cors_configuration.allow_origins) > 0 &&
      alltrue([for origin in var.cors_configuration.allow_origins : length(trimspace(origin)) > 0]) &&
      (!var.cors_configuration.allow_credentials || !contains(var.cors_configuration.allow_origins, "*"))
    )
    error_message = "CORSのallow_originsは空にできず、allow_credentials=trueの場合はワイルドカード(*)を指定できません。"
  }

  validation {
    condition = var.cors_configuration == null ? true : (
      length(var.cors_configuration.allow_methods) > 0 &&
      alltrue([for method in var.cors_configuration.allow_methods : contains(["*", "GET", "HEAD", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"], method)]) &&
      var.cors_configuration.max_age >= 0 && var.cors_configuration.max_age <= 86400 &&
      floor(var.cors_configuration.max_age) == var.cors_configuration.max_age
    )
    error_message = "CORSには有効なallow_methodsと、0〜86400の整数のmax_ageを指定してください。"
  }
}

variable "throttling" {
  description = "全ルート共通のスロットリング。rate_limitは毎秒のリクエスト数、burst_limitはバースト上限。nullの場合はAPI Gatewayの既定値を使う。"
  type = object({
    rate_limit  = number
    burst_limit = number
  })
  default = null

  validation {
    condition = var.throttling == null ? true : (
      var.throttling.rate_limit >= 0 &&
      var.throttling.burst_limit >= 0 && floor(var.throttling.burst_limit) == var.throttling.burst_limit
    )
    error_message = "throttlingのrate_limitは0以上、burst_limitは0以上の整数を指定してください。"
  }
}

variable "tags" {
  description = "Lambda、IAM、ログ、HTTP API、ステージに付与するタグ。"
  type        = map(string)
  default     = {}
}
