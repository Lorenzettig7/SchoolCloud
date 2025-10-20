variable "portal_fqdn" {
  description = "Public hostname for the portal (e.g., portal.secureschoolcloud.org)"
  type        = string
}

variable "portal_cert_arn" {
  description = "ACM cert ARN (in us-east-1) for the portal hostname"
  type        = string
}
