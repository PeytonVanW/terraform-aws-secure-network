# -----------------------------------------------------------------------------
# VPC module: a three-tier, multi-AZ network.
#
#   public (web) tier  -> route to the Internet Gateway (like a default route
#                         pointing at an ISP-facing edge router)
#   app tier           -> private; optional default route via NAT gateway
#   data tier          -> isolated; NO default route at all (local VPC only)
#
# Subnet addressing is calculated with cidrsubnet() so the plan is
# predictable and documented. See docs/ccna-to-aws.md for the subnet table.
# -----------------------------------------------------------------------------

locals {
  common_tags = merge(var.tags, {
    Module = "vpc"
  })
}

# -----------------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------------
resource "aws_vpc" "this" {
  # checkov:skip=CKV2_AWS_11:Flow logs are created by modules/flow-logs and wired in each environment; Checkov cannot follow cross-module references.
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, { Name = "${var.name}-vpc" })
}

# Lock down the default security group so nothing can accidentally use it.
# (CIS AWS Foundations Benchmark: default SG must restrict all traffic.)
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id

  # No ingress or egress blocks = deny everything.
  tags = merge(local.common_tags, { Name = "${var.name}-default-sg-locked" })
}
