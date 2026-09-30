variable "project_name" { type = string }
variable "budget_email" { type = string }
variable "budget_limit_usd" { type = number }

resource "aws_cloudwatch_log_group" "bootstrap" {
  name              = "/${var.project_name}/bootstrap"
  retention_in_days = 7
}

resource "aws_budgets_budget" "lab" {
  name         = "${var.project_name}-hard-review"
  budget_type  = "COST"
  limit_amount = tostring(var.budget_limit_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_email]
  }
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_email]
  }
}
