module "portal_edge" {
  source          = "../../modules/portal_edge"
  project         = "${var.project}-global" # avoids WAF name collision
  portal_fqdn     = var.portal_fqdn
  portal_cert_arn = aws_acm_certificate.portal.arn

  # existing bucket from dev
  s3_bucket_arn    = data.terraform_remote_state.dev.outputs.portal_bucket_arn
  s3_bucket_domain = data.terraform_remote_state.dev.outputs.portal_bucket_domain

  root_zone_id = data.aws_route53_zone.root.zone_id
}

