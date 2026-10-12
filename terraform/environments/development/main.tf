module "auth" {
  source = "../../modules/auth"

  project_name         = var.project_name
  cognito_domain       = var.cognito_domain
  callback_urls        = var.callback_urls
  logout_urls          = var.logout_urls
  google_client_id     = var.google_client_id
  google_client_secret = var.google_client_secret

  tags = {
    Project     = var.project_name
    Environment = "development"
  }
}

module "registry" {
  source = "../../modules/registry"

  repository_name = var.project_name

  tags = {
    Project     = var.project_name
    Environment = "development"
  }
}
