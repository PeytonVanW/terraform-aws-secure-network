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
  # Third-octet offsets per tier, so addresses are easy to read at a glance:
  #   public 10.0.0.x-10.0.2.x, app 10.0.10.x-..., data 10.0.20.x-...
  tier_offsets = {
    public = 0
    app    = 10
    data   = 20
  }

  # Flatten tier x AZ into one map keyed like "public-a", "app-b", "data-a".
  subnets = merge([
    for tier, offset in local.tier_offsets : {
      for idx, az in var.availability_zones :
      "${tier}-${substr(az, -1, 1)}" => {
        tier = tier
        az   = az
        cidr = cidrsubnet(var.vpc_cidr, var.subnet_newbits, offset + idx)
      }
    }
  ]...)

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

# -----------------------------------------------------------------------------
# Subnets (one resource, many instances, driven by local.subnets)
# -----------------------------------------------------------------------------
resource "aws_subnet" "this" {
  for_each = local.subnets

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  # Never hand out public IPv4 addresses automatically. AWS charges for every
  # public IPv4 address, and it is safer to opt in explicitly.
  map_public_ip_on_launch = false

  tags = merge(local.common_tags, {
    Name = "${var.name}-${each.key}"
    Tier = each.value.tier
  })
}
