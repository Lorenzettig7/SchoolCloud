variable "project_name" {
  type    = string
  default = "schoolcloud"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

# keep this only if your identity module needs it
variable "github_repo_sub" {
  type    = string
  default = ""
}
