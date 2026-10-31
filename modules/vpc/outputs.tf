output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "subnet_plan" {
  description = "Every subnet with its tier, AZ, and CIDR. Handy for documentation."
  value       = local.subnets
}

output "subnet_ids_by_tier" {
  description = "Map of tier name to list of subnet IDs."
  value = {
    for tier in keys(local.tier_offsets) :
    tier => [for k, s in aws_subnet.this : s.id if local.subnets[k].tier == tier]
  }
}

output "subnet_cidrs_by_tier" {
  description = "Map of tier name to list of subnet CIDRs (known at plan time)."
  value = {
    for tier in keys(local.tier_offsets) :
    tier => [for k, s in local.subnets : s.cidr if s.tier == tier]
  }
}

output "route_table_ids" {
  description = "Map of tier name to route table ID."
  value       = { for tier, rt in aws_route_table.tier : tier => rt.id }
}

output "s3_prefix_list_id" {
  description = "Prefix list ID of the S3 gateway endpoint (null if disabled). Use it in security group rules."
  value       = var.enable_s3_gateway_endpoint ? aws_vpc_endpoint.s3[0].prefix_list_id : null
}

output "nat_gateway_enabled" {
  description = "Whether a (billable) NAT gateway was created."
  value       = var.enable_nat_gateway
}
