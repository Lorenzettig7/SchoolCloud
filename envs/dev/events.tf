resource "aws_lambda_function" "events" {
  function_name = "${var.project}-demo-events"
  role          = aws_iam_role.events.arn
  runtime       = "python3.12"
  handler       = "events/handler.handler"

  filename         = "${path.module}/../../apps/events.zip"
  source_code_hash = filebase64sha256("${path.module}/../../apps/events.zip")
}
