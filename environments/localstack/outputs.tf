output "vpc_id" {
  description = "VPC ID."
  value       = module.vpc.vpc_id
}

output "subnet_plan" {
  description = "Subnet addressing plan."
  value       = module.vpc.subnet_plan
}

output "security_group_ids" {
  description = "Security group IDs by tier."
  value       = module.security.security_group_ids
}

output "nacl_rule_table" {
  description = "Readable NACL policy."
  value       = module.security.nacl_rule_table
}

output "flow_log_group" {
  description = "CloudWatch log group for flow logs (null if disabled)."
  value       = var.enable_flow_logs ? module.flow_logs[0].log_group_name : null
}
