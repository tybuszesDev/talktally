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

# Stored as GitHub Actions secrets (README.md), so the account ID stays out of
# the public workflow logs.
output "ci_plan_role_arn" {
  description = "IAM role that pull request jobs assume for terraform plan."
  value       = aws_iam_role.ci_plan.arn
}

output "ci_deploy_role_arn" {
  description = "IAM role that jobs in the dev and prod environments assume for terraform apply."
  value       = aws_iam_role.ci_deploy.arn
}

# Every IAM role in envs/dev and envs/prod sets this as permissions_boundary.
output "workload_boundary_policy_arn" {
  description = "Permissions boundary required on every role the deploy role creates."
  value       = aws_iam_policy.workload_boundary.arn
}
