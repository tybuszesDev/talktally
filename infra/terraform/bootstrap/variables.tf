variable "alert_email" {
  description = "Email address that receives cost alerts. Set it in private.auto.tfvars, which git ignores."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.alert_email))
    error_message = "The alert_email value must be an email address."
  }
}

variable "monthly_budget_usd" {
  description = "Monthly cost budget in USD, counted before credits (ADR-0002)."
  type        = number
  default     = 10
}

variable "anomaly_threshold_usd" {
  description = "Total cost impact in USD from which Cost Anomaly Detection sends an alert."
  type        = number
  default     = 1
}
