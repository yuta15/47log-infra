module "database" {
  source = "../../modules/database"

  enable_database_modules = true
  tables                  = local.tables
}
