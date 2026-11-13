# One topic for every alert: budgets, cost anomalies and, later, CloudWatch
# alarms (ADR-0015). The owner's email address subscribes to it.
#
# Not encrypted: AWS Budgets needs extra KMS key policy permissions to publish to
# an encrypted topic, and the AWS-managed key's policy cannot be changed. A
# customer managed key would cost about 1 USD per month, 10% of the budget.
# Alerts contain only cost data, no user content.
resource "aws_sns_topic" "alerts" {
  name = "talktally-alerts"
}

resource "aws_sns_topic_policy" "alerts" {
  arn = aws_sns_topic.alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Same as the default topic policy: principals of this account may use
        # and manage the topic.
        Sid       = "AccountOwnerAccess"
        Effect    = "Allow"
        Principal = { AWS = "*" }
        Action = [
          "SNS:AddPermission",
          "SNS:DeleteTopic",
          "SNS:GetTopicAttributes",
          "SNS:ListSubscriptionsByTopic",
          "SNS:Publish",
          "SNS:Receive",
          "SNS:RemovePermission",
          "SNS:SetTopicAttributes",
          "SNS:Subscribe",
        ]
        Resource = aws_sns_topic.alerts.arn
        Condition = {
          StringEquals = {
            "AWS:SourceOwner" = local.account_id
          }
        }
      },
      {
        Sid       = "AllowBudgetsToPublish"
        Effect    = "Allow"
        Principal = { Service = "budgets.amazonaws.com" }
        Action    = "SNS:Publish"
        Resource  = aws_sns_topic.alerts.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.account_id
          }
          ArnLike = {
            "aws:SourceArn" = "arn:aws:budgets::${local.account_id}:*"
          }
        }
      },
      {
        Sid       = "AllowCostAnomalyDetectionToPublish"
        Effect    = "Allow"
        Principal = { Service = "costalerts.amazonaws.com" }
        Action    = "SNS:Publish"
        Resource  = aws_sns_topic.alerts.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.account_id
          }
        }
      },
    ]
  })
}

# AWS sends a confirmation email; the subscription stays pending until the link
# in it is clicked.
resource "aws_sns_topic_subscription" "alerts_email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}
