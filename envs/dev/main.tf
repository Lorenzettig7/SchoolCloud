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
