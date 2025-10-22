resource "aws_acm_certificate" "portal" {
  provider                  = aws.us_east_1
  domain_name               = var.portal_fqdn
  subject_alternative_names = []
  validation_method         = "DNS"

  lifecycle { create_before_destroy = true }
}

resource "aws_route53_record" "portal_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.portal.domain_validation_options :
    dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  }

  zone_id         = data.aws_route53_zone.root.zone_id
  name            = each.value.name
  type            = each.value.type
  ttl             = 60
  records         = [each.value.value]
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "portal" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.portal.arn
  validation_record_fqdns = [for r in aws_route53_record.portal_cert_validation : r.fqdn]
}
