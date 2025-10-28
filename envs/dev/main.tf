// envs/dev/main.tf
module "kms" {
  source  = "../../modules/kms"
  project = var.project
}

module "identity" {
  source                   = "../../modules/identity"
  project                  = var.project
  repo_sub                 = var.repo_sub
  region                   = var.region
  permissions_boundary_arn = var.permissions_boundary_arn
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

  auth_lambda_arn     = aws_lambda_function.auth.arn
  identity_lambda_arn = module.identity.identity_lambda_arn
  events_lambda_arn   = module.identity.events_lambda_arn

}
resource "aws_dynamodb_table" "users" {
  name         = "schoolcloud-demo-users"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user_id"

  attribute {
    name = "user_id"
    type = "S"
  }
}

resource "aws_dynamodb_table" "events" {
  name         = "schoolcloud-demo-events"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "event_id"

  attribute {
    name = "event_id"
    type = "S"
  }
}
