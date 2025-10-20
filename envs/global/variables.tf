variable "domain_root" {
  type        = string
  default     = "secureschoolcloud.org"
  description = "Root public DNS zone"
}

variable "portal_fqdn" {
  type        = string
  default     = "portal.secureschoolcloud.org"
  description = "Production hostname for the portal"
}
