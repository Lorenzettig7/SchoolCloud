resource "aws_lambda_function" "identity" {
  function_name = "${var.project}-demo-identity"
  role          = aws_iam_role.auth.arn
  runtime       = "python3.12"
  handler       = "identity/handler.handler"

  filename         = "${path.module}/../../apps/identity.zip"
  source_code_hash = filebase64sha256("${path.module}/../../apps/identity.zip")
}


