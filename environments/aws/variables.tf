variable "region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Name prefix for all resources."
  type        = string
  default     = "lab"
}

variable "vpc_cidr" {
  description = "VPC CIDR block."
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "AZs to deploy into."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "admin_cidrs" {
  description = "CIDRs allowed to SSH to the web tier (your IP /32). Empty disables SSH."
  type        = list(string)
  default     = []
}

variable "enable_flow_logs" {
  description = "Create VPC flow logs to CloudWatch. Small data volumes stay in the free tier; off by default to be safe."
  type        = bool
  default     = false
}

variable "enable_nat_gateway" {
  description = "Create a NAT gateway. BILLABLE (hourly + per GB). Leave false unless you destroy it the same day."
  type        = bool
  default     = false
}

variable "budget_alert_email" {
  description = "Email for AWS Budgets alerts. Set in terraform.tfvars (git-ignored). Empty = no budget created."
  type        = string
  default     = ""
}

variable "monthly_budget_usd" {
  description = "Monthly spend that triggers an alert email."
  type        = number
  default     = 1
}
