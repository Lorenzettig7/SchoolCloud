# envs/dev/events.tf
resource "aws_lambda_function" "events" {
  function_name = "${var.project}-demo-events"
  role          = aws_iam_role.auth.arn
  runtime       = "python3.12"
  handler       = "events/handler.handler"
  filename      = "${path.module}/../../apps/events/function.zip"
}

resource "aws_lambda_permission" "apigw_events" {
  statement_id  = "AllowAPIGatewayInvokeEvents"
  action        = "lambda:InvokeFunction"
  function      = aws_lambda_function.events.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${module.demo_identity_api.execution_arn}/*/*"
}
