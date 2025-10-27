// envs/dev/variables.tf
variable "project" {
  type    = string
  default = "schoolcloud"
}

variable "region" {
  type    = string
  default = "us-east-1"
}

# Only needed if your identity module uses it (it does)
variable "repo_sub" {
  type        = string
  description = "GitHub subdirectory"
}

variable "permissions_boundary_arn" {
  type        = string
  description = "IAM Permissions Boundary ARN"
}