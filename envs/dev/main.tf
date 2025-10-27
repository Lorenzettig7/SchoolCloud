// envs/dev/main.tf
module "kms" {
  source  = "../../modules/kms"
  project = var.project
}

module "identity" {
  source   = "../../modules/identity"
  project  = var.project
  repo_sub = var.repo_sub
}

module "portal_bucket" {
  source  = "../../modules/portal_bucket"
  project = var.project
  region  = var.region
}


module "demo_identity_api" {
  source                   = "../../modules/demo_identity_api"
  project                  = var.project
  region                   = var.region
  permissions_boundary_arn = var.permissions_boundary_arn

  auth_lambda_arn         = aws_lambda_function.auth.arn
  identity_lambda_arn = module.identity.identity_lambda_arn
  events_lambda_arn   = module.identity.events_lambda_arn

}
