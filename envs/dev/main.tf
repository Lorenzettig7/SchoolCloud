module "kms" {
  source = "../../modules/kms"
  # project = var.project_name   # <-- comment this out
}

module "identity" {
  source   = "../../modules/identity"
  project  = var.project_name
  repo_sub = var.github_repo_sub
}
module "edge_portal" {
  source  = "../../modules/edge_portal"
  project = var.project_name
  region  = "us-east-1"
}