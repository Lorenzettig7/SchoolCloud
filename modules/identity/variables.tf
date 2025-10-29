variable "repo_sub" {
  type = string
}
variable "project" {
  type        = string
  description = "Project name/prefix"
}

variable "region" {
  type        = string
  description = "AWS region for these Lambdas"
}

variable "permissions_boundary_arn" {
  type        = string
  description = "IAM Permissions Boundary ARN (or null)"
  default     = null
}
variable "create_boundary" {
  type    = bool
  default = false
}
