# AWS created this monitor when Cost Explorer was first opened. An account can
# have only one AWS services monitor, so Terraform adopts the existing one with
# a one-time `terraform import` (see README.md) instead of creating another.
# The arguments must match the existing monitor, or Terraform would replace it.
resource "aws_ce_anomaly_monitor" "services" {
  name              = "Default-Services-Monitor"
  monitor_type      = "DIMENSIONAL"
  monitor_dimension = "SERVICE"
}

# Individual alerts (IMMEDIATE) as soon as an anomaly with a total impact of at
# least var.anomaly_threshold_usd is found. This frequency requires an SNS
# subscriber. The default AWS daily summary subscription stays as it is.
resource "aws_ce_anomaly_subscription" "alerts" {
  name             = "talktally-anomalies"
  frequency        = "IMMEDIATE"
  monitor_arn_list = [aws_ce_anomaly_monitor.services.arn]

  subscriber {
    type    = "SNS"
    address = aws_sns_topic.alerts.arn
  }

  threshold_expression {
    dimension {
      key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
      match_options = ["GREATER_THAN_OR_EQUAL"]
      values        = [tostring(var.anomaly_threshold_usd)]
    }
  }

  depends_on = [aws_sns_topic_policy.alerts]
}
