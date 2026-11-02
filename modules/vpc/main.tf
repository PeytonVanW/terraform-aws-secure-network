# Three-tier VPC spread across availability zones, so losing one AZ doesn't take everything down.
#
#   web tier:  public, default route to the Internet Gateway (like a default route toward an ISP edge router)
#   app tier:  private, gets out only through an optional NAT gateway
#   data tier: isolated, no default route, can only talk inside the VPC
#
# cidrsubnet() builds the subnets, so the address plan is predictable.
# docs/ccna-to-aws.md has the full subnet table.

locals {
  # Each tier gets its own third octet, so you can tell the tier from the IP:
  # public 10.0.0.x to 10.0.2.x, app starts at 10.0.10.x, data starts at 10.0.20.x
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

resource "aws_vpc" "this" {
  # checkov:skip=CKV2_AWS_11:Flow logs are created by modules/flow-logs and wired in each environment; Checkov cannot follow cross-module references.
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, { Name = "${var.name}-vpc" })
}

# Lock down the default security group so nothing lands in it by accident.
# The CIS AWS Foundations Benchmark requires this.
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id

  # No ingress or egress blocks = deny everything.
  tags = merge(local.common_tags, { Name = "${var.name}-default-sg-locked" })
}

# One subnet resource with an instance per tier and AZ, built from local.subnets.
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

# Internet Gateway and one route table per tier.
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.common_tags, { Name = "${var.name}-igw" })
}

resource "aws_route_table" "tier" {
  for_each = local.tier_offsets

  vpc_id = aws_vpc.this.id
  tags   = merge(local.common_tags, { Name = "${var.name}-${each.key}-rt", Tier = each.key })
}

# Equivalent to: ip route 0.0.0.0 0.0.0.0 <igw>
resource "aws_route" "public_default" {
  route_table_id         = aws_route_table.tier["public"].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "this" {
  for_each = local.subnets

  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_route_table.tier[each.value.tier].id
}

# NAT gateway for the app tier. Off by default because AWS bills it by the hour.
resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? 1 : 0
  domain = "vpc"
  tags   = merge(local.common_tags, { Name = "${var.name}-nat-eip" })
}

resource "aws_nat_gateway" "this" {
  count = var.enable_nat_gateway ? 1 : 0

  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.this["public-${substr(var.availability_zones[0], -1, 1)}"].id
  tags          = merge(local.common_tags, { Name = "${var.name}-nat" })

  depends_on = [aws_internet_gateway.this]
}

# Equivalent to: ip route 0.0.0.0 0.0.0.0 <nat>  (only when NAT is enabled)
resource "aws_route" "app_default_via_nat" {
  count = var.enable_nat_gateway ? 1 : 0

  route_table_id         = aws_route_table.tier["app"].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[0].id
}

# The data tier route table has no default route on purpose. It only has the
# implicit local route for the VPC CIDR, like a stub network with no gateway
# of last resort.

# S3 gateway endpoint. It's free, and the private tiers reach S3 without touching the internet.
resource "aws_vpc_endpoint" "s3" {
  count = var.enable_s3_gateway_endpoint ? 1 : 0

  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids = [
    aws_route_table.tier["app"].id,
    aws_route_table.tier["data"].id,
  ]

  tags = merge(local.common_tags, { Name = "${var.name}-s3-endpoint" })
}
