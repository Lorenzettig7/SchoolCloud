variable "project" {
  description = "Project name for naming and tags (e.g., schoolcloud)"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "permissions_boundary_arn" {
  description = "Optional IAM permissions boundary ARN"
  type        = string
  default     = null
}

# Lambda ARNs to integrate
variable "auth_lambda_arn" {
  description = "ARN of the auth Lambda function"
  type        = string
}

variable "identity_lambda_arn" {
  description = "ARN of the identity Lambda function"
  type        = string
}

variable "events_lambda_arn" {
  description = "ARN of the events Lambda function"
  type        = string
}
