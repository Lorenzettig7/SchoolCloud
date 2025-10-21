variable "root_domain" {
  type    = string
  default = "secureschoolcloud.org."
}

data "aws_route53_zone" "root" {
  name         = "secureschoolcloud.org."
  private_zone = false
}