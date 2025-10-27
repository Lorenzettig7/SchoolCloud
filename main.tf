module "demo_identity_api" {
  source                   = "./modules/demo_identity_api"
  project                  = var.project
  region                   = var.region
  permissions_boundary_arn = var.permissions_boundary_arn
}


output "api_base_url" { value = module.demo_identity_api.api_base_url }
output "users_table" { value = module.demo_identity_api.users_table }
output "events_table" { value = module.demo_identity_api.events_table }
