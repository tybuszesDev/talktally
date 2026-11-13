# Used by later stacks: the backend of envs/dev and envs/prod (F-13) and
# CloudWatch alarms (F-26).
output "state_bucket_name" {
  description = "S3 bucket that stores Terraform state."
  value       = aws_s3_bucket.state.bucket
}

output "alerts_topic_arn" {
  description = "SNS topic that delivers alerts to the owner."
  value       = aws_sns_topic.alerts.arn
}
