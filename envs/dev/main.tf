// envs/dev/main.tf
module "kms" {
  source  = "../../modules/kms"
  project = var.project
}

module "identity" {
  source   = "../../modules/identity"
  project  = var.project
  repo_sub = var.github_repo_sub
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
  permissions_boundary_arn = null  # set if your org requires it

  # Use the Lambda we just created
  auth_lambda_arn     = aws_lambda_function.auth.arn
  identity_lambda_arn = ""  # leave empty until you add it
  events_lambda_arn   = ""  # leave empty until you add it

  # Names for permissions (module skips permission resource if name == "")
  auth_lambda_name     = aws_lambda_function.auth.function_name
  identity_lambda_name = ""
  events_lambda_name   = ""
}
