variable "project" { type = string }

resource "aws_kms_key" "default" {
  description             = "KMS CMK for ${var.project}"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

resource "aws_kms_alias" "default" {
  name          = "alias/${var.project}/default"
  target_key_id = aws_kms_key.default.key_id
}
