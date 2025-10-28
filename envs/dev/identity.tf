# envs/dev/identity.tf
resource "aws_lambda_function" "identity" {
  function_name = "${var.project}-demo-identity"
  role          = aws_iam_role.auth.arn           # or a separate role if you prefer
  runtime       = "python3.12"
  handler       = "identity/handler.handler"
  filename      = "${path.module}/../../apps/identity/function.zip" # or s3_bucket/s3_key
}

resource "aws_lambda_permission" "apigw_identity" {
  statement_id  = "AllowAPIGatewayInvokeIdentity"
  action        = "lambda:InvokeFunction"
  function      = aws_lambda_function.identity.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${module.demo_identity_api.execution_arn}/*/*"
}
