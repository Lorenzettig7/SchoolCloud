module "kms" {
  source = "../../modules/kms"
}

module "identity" {
  source   = "../../modules/identity"
  project  = var.project_name
  repo_sub = var.github_repo_sub
}

module "portal_bucket" {
  source  = "../../modules/portal_bucket"
  project = var.project_name
  region  = var.aws_region
}
