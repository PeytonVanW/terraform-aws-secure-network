output "log_group_name" {
  description = "CloudWatch log group receiving the flow logs."
  value       = aws_cloudwatch_log_group.this.name
}

output "flow_log_id" {
  description = "ID of the VPC flow log."
  value       = aws_flow_log.this.id
}

output "iam_role_arn" {
  description = "IAM role the flow-logs service assumes."
  value       = aws_iam_role.this.arn
}
