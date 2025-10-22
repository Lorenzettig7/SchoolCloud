variable "project" { type = string }
variable "portal_fqdn" { type = string }     # e.g. portal.secureschoolcloud.org
variable "portal_cert_arn" { type = string } # ACM cert in us-east-1 for CloudFront
variable "s3_bucket_arn" { type = string }
variable "s3_bucket_domain" { type = string }
variable "root_zone_id" { type = string } # Hosted zone where "portal" lives
