variable "root_zone_id" {
  type    = string
  default = "Z09697821Y1MUDCESVL4E" # your real zone ID
}

data "aws_route53_zone" "root" {
  zone_id = var.root_zone_id
}

resource "aws_route53_record" "portal_alias_a" {
  zone_id = data.aws_route53_zone.root.zone_id
  name    = "portal.secureschoolcloud.org"
  type    = "A"

  alias {
    name                   = module.edge_portal.portal_domain
    zone_id                = module.edge_portal.cf_hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "portal_alias_aaaa" {
  zone_id = data.aws_route53_zone.root.zone_id
  name    = "portal.secureschoolcloud.org"
  type    = "AAAA"

  alias {
    name                   = module.edge_portal.portal_domain
    zone_id                = module.edge_portal.cf_hosted_zone_id
    evaluate_target_health = false
  }
}
