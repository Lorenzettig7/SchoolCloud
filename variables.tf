variable "project" { type = string }

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "permissions_boundary_arn" {
  type    = string
  default = null
}
variable "github_repo_sub" {
  type        = string
  description = "Subject claim for GitHub OIDC (e.g., repo:owner/repo:ref)"
  default     = null
}
