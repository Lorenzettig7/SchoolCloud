resource "aws_route53_record" "portal_alias_a" {
  zone_id = data.aws_route53_zone.root.zone_id
  name    = "portal"
  type    = "A"
  alias {
    name                   = data.terraform_remote_state.dev.outputs.portal_domain_name
    zone_id                = data.terraform_remote_state.dev.outputs.portal_hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "portal_alias_aaaa" {
  zone_id = data.aws_route53_zone.root.zone_id
  name    = "portal"
  type    = "AAAA"
  alias {
    name                   = data.terraform_remote_state.dev.outputs.portal_domain_name
    zone_id                = data.terraform_remote_state.dev.outputs.portal_hosted_zone_id
    evaluate_target_health = false
  }
}
