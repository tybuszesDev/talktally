# Monthly cost budget (ADR-0002). Credits are not subtracted (include_credit =
# false): while the free plan credits pay the bill, the net cost is 0 USD, and
# an alarm on net cost would stay silent until the credits are gone.
resource "aws_budgets_budget" "monthly" {
  name         = "talktally-monthly"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_types {
    include_credit = false
  }

  # Early warning: half of the budget is spent.
  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 50
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [aws_sns_topic.alerts.arn]
  }

  # The budget is spent.
  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 100
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [aws_sns_topic.alerts.arn]
  }

  # AWS forecasts that the month will end above the budget.
  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 100
    threshold_type            = "PERCENTAGE"
    notification_type         = "FORECASTED"
    subscriber_sns_topic_arns = [aws_sns_topic.alerts.arn]
  }

  # Budgets checks its permission to publish when the budget is saved.
  depends_on = [aws_sns_topic_policy.alerts]
}
