output "identity_lambda_arn" {
  value = aws_lambda_function.identity.arn
}

output "events_lambda_arn" {
  value = aws_lambda_function.events.arn
}
