# Root module for a real AWS account. The defaults cost $0: VPCs, subnets,
# route tables, internet gateways, security groups, NACLs, and S3 gateway
# endpoints have no hourly charge, and nothing gets a public IPv4 address
# unless the NAT gateway is turned on.
#
# Run `terraform destroy` at the end of every session so nothing is left
# running between labs.

module "vpc" {
  source = "../../modules/vpc"

  name               = var.name
  region             = var.region
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones

  enable_nat_gateway         = var.enable_nat_gateway
  enable_s3_gateway_endpoint = true # free, and S3 traffic stays off the internet
}

module "security" {
  source = "../../modules/security"

  name                 = var.name
  vpc_id               = module.vpc.vpc_id
  subnet_ids_by_tier   = module.vpc.subnet_ids_by_tier
  subnet_cidrs_by_tier = module.vpc.subnet_cidrs_by_tier
  admin_cidrs          = var.admin_cidrs

  enable_s3_access  = true
  s3_prefix_list_id = module.vpc.s3_prefix_list_id

  # The app tier only gets outbound HTTPS when a NAT gateway exists to carry it.
  allow_app_internet_https = var.enable_nat_gateway
}

module "flow_logs" {
  source = "../../modules/flow-logs"
  count  = var.enable_flow_logs ? 1 : 0

  name   = var.name
  vpc_id = module.vpc.vpc_id
}

# Cost guardrail for a $0 lab. AWS Budgets emails me before a surprise bill,
# and AWS doesn't charge for the first couple of budgets. No email set means
# no budget, so the address never has to live in the repo.
resource "aws_budgets_budget" "monthly" {
  count = var.budget_alert_email == "" ? 0 : 1

  name         = "${var.name}-monthly-guardrail"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  # Early warning at 50% of actual spend, while there's still time to destroy.
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 50
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_alert_email]
  }

  # Fires when AWS forecasts the month will pass 100%, which catches a
  # resource left running.
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.budget_alert_email]
  }
}
