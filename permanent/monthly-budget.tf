provider "aws" {
    region = "us-east-1"
}

resource "aws_budgets_budget" "monthly_budget" {
    name = "monthly-budget"
    time_unit = "MONTHLY"
    budget_type = "COST"
    limit_amount = "13"
    limit_unit = "USD"
    time_period_start = "2024-09-01_00:00"

    notification {
        comparison_operator = "GREATER_THAN"
        threshold = 100
        threshold_type = "PERCENTAGE"
        notification_type = "FORECASTED"
        subscriber_email_addresses = ["sully@sullivandigitalconsulting.com"]
    }
}