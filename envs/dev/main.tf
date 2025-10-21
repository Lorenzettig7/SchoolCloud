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
  source          = "../../modules/edge_portal"
  project         = "schoolcloud"
  region          = "us-east-1"
  portal_fqdn     = "portal.secureschoolcloud.org"
  portal_cert_arn = "arn:aws:acm:us-east-1:713881788173:certificate/ea0beb70-e153-4b3c-983a-201945807a2e"
}

