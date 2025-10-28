resource "aws_lambda_function" "identity" {
  function_name = "${var.project}-demo-identity"
  role          = aws_iam_role.auth.arn
  runtime       = "python3.12"
  handler       = "identity/handler.handler"

  filename         = "${path.module}/../../apps/identity.zip"
  source_code_hash = filebase64sha256("${path.module}/../../apps/identity.zip")
}


resource "aws_lambda_permission" "apigw_identity" {
  statement_id  = "AllowAPIGatewayInvokeIdentity"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.identity.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${module.demo_identity_api.execution_arn}/*/*"
}

