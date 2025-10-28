resource "aws_lambda_function" "events" {
  function_name = "${var.project}-demo-events"
  role          = aws_iam_role.auth.arn
  runtime       = "python3.12"
  handler       = "events/handler.handler"

  filename         = "${path.module}/../../apps/events.zip"
  source_code_hash = filebase64sha256("${path.module}/../../apps/events.zip")
}

resource "aws_lambda_permission" "apigw_events" {
  statement_id  = "AllowAPIGatewayInvokeEvents"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.events.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${module.demo_identity_api.execution_arn}/*/*"
}
