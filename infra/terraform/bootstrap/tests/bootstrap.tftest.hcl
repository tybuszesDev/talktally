# Unit tests for the bootstrap stack. The AWS provider is mocked, so nothing is
# created in AWS and no credentials are needed.
# Run: terraform -chdir=infra/terraform/bootstrap init -backend=false
#      terraform -chdir=infra/terraform/bootstrap test

mock_provider "aws" {
  # Use the defaults below already during plan, so plan-only runs can check
  # values built from them, such as policies that contain ARNs.
  override_during = plan

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  mock_resource "aws_s3_bucket" {
    defaults = {
      arn = "arn:aws:s3:::talktally-tfstate-3af2cc3e"
    }
  }

  mock_resource "aws_sns_topic" {
    defaults = {
      arn = "arn:aws:sns:eu-central-1:123456789012:talktally-alerts"
    }
  }

  mock_resource "aws_ce_anomaly_monitor" {
    defaults = {
      arn = "arn:aws:ce::123456789012:anomalymonitor/00000000-0000-0000-0000-000000000000"
    }
  }
}

variables {
  alert_email = "alerts@example.com"
}

run "state_bucket_is_versioned_encrypted_and_private" {
  command = plan

  assert {
    condition     = aws_s3_bucket.state.bucket == "talktally-tfstate-3af2cc3e"
    error_message = "The state bucket name must match the backend block in versions.tf."
  }

  assert {
    condition     = aws_s3_bucket_versioning.state.versioning_configuration[0].status == "Enabled"
    error_message = "State bucket versioning must be enabled."
  }

  assert {
    condition     = one(aws_s3_bucket_server_side_encryption_configuration.state.rule).apply_server_side_encryption_by_default[0].sse_algorithm == "AES256"
    error_message = "State bucket must use SSE-S3 encryption."
  }

  assert {
    condition = alltrue([
      aws_s3_bucket_public_access_block.state.block_public_acls,
      aws_s3_bucket_public_access_block.state.block_public_policy,
      aws_s3_bucket_public_access_block.state.ignore_public_acls,
      aws_s3_bucket_public_access_block.state.restrict_public_buckets,
    ])
    error_message = "All four public access blocks must be on."
  }

  assert {
    condition     = jsondecode(aws_s3_bucket_policy.state.policy).Statement[0].Condition.Bool["aws:SecureTransport"] == "false"
    error_message = "The bucket policy must deny requests without TLS."
  }
}

run "budget_counts_cost_before_credits_and_alerts_the_topic" {
  command = plan

  assert {
    condition     = aws_budgets_budget.monthly.limit_amount == "10" && aws_budgets_budget.monthly.limit_unit == "USD"
    error_message = "The monthly budget must be 10 USD."
  }

  assert {
    condition     = aws_budgets_budget.monthly.cost_types[0].include_credit == false
    error_message = "The budget must count cost before credits."
  }

  assert {
    condition = toset([for n in aws_budgets_budget.monthly.notification : "${n.notification_type}:${n.threshold}"]) == toset([
      "ACTUAL:50",
      "ACTUAL:100",
      "FORECASTED:100",
    ])
    error_message = "The budget must alert at 50% and 100% actual and 100% forecast."
  }

  assert {
    condition     = alltrue([for n in aws_budgets_budget.monthly.notification : n.subscriber_sns_topic_arns == toset([aws_sns_topic.alerts.arn])])
    error_message = "Every budget notification must go to the alerts topic."
  }
}

run "alerts_topic_accepts_cost_services_and_emails_the_owner" {
  command = plan

  assert {
    condition = toset([
      for s in jsondecode(aws_sns_topic_policy.alerts.policy).Statement : s.Principal.Service
      if can(s.Principal.Service)
    ]) == toset(["budgets.amazonaws.com", "costalerts.amazonaws.com"])
    error_message = "Only AWS Budgets and Cost Anomaly Detection may publish as services."
  }

  assert {
    condition     = aws_sns_topic_subscription.alerts_email.protocol == "email" && aws_sns_topic_subscription.alerts_email.endpoint == "alerts@example.com"
    error_message = "The alert email address must subscribe to the topic."
  }
}

run "anomaly_alerts_are_immediate_from_one_dollar" {
  command = plan

  assert {
    condition     = aws_ce_anomaly_subscription.alerts.frequency == "IMMEDIATE"
    error_message = "Anomaly alerts must be sent immediately."
  }

  assert {
    condition     = aws_ce_anomaly_subscription.alerts.threshold_expression[0].dimension[0].values == toset(["1"])
    error_message = "Anomaly alerts must start at 1 USD."
  }

  assert {
    condition     = one(aws_ce_anomaly_subscription.alerts.subscriber).address == aws_sns_topic.alerts.arn
    error_message = "Anomaly alerts must go to the alerts topic."
  }
}

run "rejects_an_invalid_alert_email" {
  command = plan

  variables {
    alert_email = "not-an-email"
  }

  expect_failures = [var.alert_email]
}
