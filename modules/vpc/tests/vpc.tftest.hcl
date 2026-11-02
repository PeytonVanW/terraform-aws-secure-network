# Unit tests for the vpc module. Run from modules/vpc with: terraform test
# The AWS provider is mocked, so these run in seconds with no account,
# credentials, or LocalStack. That also makes them free to run in CI.

mock_provider "aws" {}

variables {
  name               = "test"
  region             = "us-east-1"
  vpc_cidr           = "10.0.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b"]
}

run "creates_one_subnet_per_tier_per_az" {
  command = plan

  assert {
    condition     = length(aws_subnet.this) == 6
    error_message = "Expected 3 tiers x 2 AZs = 6 subnets."
  }
}

run "subnet_addressing_follows_the_plan" {
  command = plan

  assert {
    condition     = aws_subnet.this["public-a"].cidr_block == "10.0.0.0/24"
    error_message = "public-a should be 10.0.0.0/24."
  }

  assert {
    condition     = aws_subnet.this["app-b"].cidr_block == "10.0.11.0/24"
    error_message = "app-b should be 10.0.11.0/24."
  }

  assert {
    condition     = aws_subnet.this["data-a"].cidr_block == "10.0.20.0/24"
    error_message = "data-a should be 10.0.20.0/24."
  }
}

run "no_subnet_auto_assigns_public_ips" {
  command = plan

  assert {
    condition     = alltrue([for s in aws_subnet.this : s.map_public_ip_on_launch == false])
    error_message = "Subnets must not auto-assign public IPv4 addresses."
  }
}

run "nat_gateway_is_off_by_default" {
  command = plan

  assert {
    condition     = length(aws_nat_gateway.this) == 0 && length(aws_route.app_default_via_nat) == 0
    error_message = "NAT gateway costs money and must be opt-in."
  }
}

run "nat_gateway_can_be_enabled" {
  command = plan

  variables {
    enable_nat_gateway = true
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 1 && length(aws_route.app_default_via_nat) == 1
    error_message = "enable_nat_gateway = true should create one NAT gateway and an app-tier default route."
  }
}

run "only_public_tier_has_internet_route" {
  command = plan

  assert {
    condition     = aws_route.public_default.destination_cidr_block == "0.0.0.0/0"
    error_message = "Public tier needs a default route to the IGW."
  }

  assert {
    condition     = output.subnet_cidrs_by_tier["data"] == ["10.0.20.0/24", "10.0.21.0/24"]
    error_message = "Data tier CIDRs should be 10.0.20.0/24 and 10.0.21.0/24."
  }
}

run "three_azs_scale_cleanly" {
  command = plan

  variables {
    availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
  }

  assert {
    condition     = length(aws_subnet.this) == 9 && aws_subnet.this["data-c"].cidr_block == "10.0.22.0/24"
    error_message = "Three AZs should produce 9 subnets; data-c should be 10.0.22.0/24."
  }
}

run "rejects_invalid_cidr" {
  command = plan

  variables {
    vpc_cidr = "10.0.0.0/33"
  }

  expect_failures = [var.vpc_cidr]
}

run "rejects_public_address_space" {
  command = plan

  variables {
    vpc_cidr = "8.8.0.0/16"
  }

  expect_failures = [var.vpc_cidr]
}

run "rejects_single_az" {
  command = plan

  variables {
    availability_zones = ["us-east-1a"]
  }

  expect_failures = [var.availability_zones]
}
