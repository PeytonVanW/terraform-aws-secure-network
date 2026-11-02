# Unit tests for the security module. Run from modules/security with: terraform test
# These check that the firewall rules actually do what the README says they do,
# so a bad edit to a NACL or security group fails here before it reaches AWS.

mock_provider "aws" {}

variables {
  name   = "test"
  vpc_id = "vpc-0123456789abcdef0"

  subnet_ids_by_tier = {
    public = ["subnet-pub-a", "subnet-pub-b"]
    app    = ["subnet-app-a", "subnet-app-b"]
    data   = ["subnet-dat-a", "subnet-dat-b"]
  }

  subnet_cidrs_by_tier = {
    public = ["10.0.0.0/24", "10.0.1.0/24"]
    app    = ["10.0.10.0/24", "10.0.11.0/24"]
    data   = ["10.0.20.0/24", "10.0.21.0/24"]
  }
}

run "security_groups_are_chained_not_cidr_based" {
  command = apply

  assert {
    condition     = aws_vpc_security_group_ingress_rule.app_from_web.referenced_security_group_id == aws_security_group.web.id
    error_message = "App tier must only accept traffic from the web security group."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.db_from_app.referenced_security_group_id == aws_security_group.app.id
    error_message = "Data tier must only accept traffic from the app security group."
  }
}

run "only_https_is_open_to_the_internet" {
  command = plan

  assert {
    condition     = aws_vpc_security_group_ingress_rule.web_https.from_port == 443 && aws_vpc_security_group_ingress_rule.web_https.cidr_ipv4 == "0.0.0.0/0"
    error_message = "Web tier should allow 443 from anywhere."
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.web_ssh_admin) == 0
    error_message = "With no admin_cidrs, no SSH rules should exist."
  }
}

run "ssh_is_limited_to_admin_cidrs" {
  command = plan

  variables {
    admin_cidrs = ["203.0.113.10/32"]
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.web_ssh_admin["203.0.113.10/32"].from_port == 22
    error_message = "SSH rule should exist for the admin /32."
  }

  assert {
    condition     = aws_network_acl_rule.this["public-in-110"].cidr_block == "203.0.113.10/32"
    error_message = "Public NACL should permit SSH only from the admin /32."
  }
}

run "refuses_ssh_from_anywhere" {
  command = plan

  variables {
    admin_cidrs = ["0.0.0.0/0"]
  }

  expect_failures = [var.admin_cidrs]
}

run "data_tier_explicitly_denies_web_tier_first" {
  command = plan

  assert {
    condition     = aws_network_acl_rule.this["data-in-50"].rule_action == "deny" && aws_network_acl_rule.this["data-in-50"].cidr_block == "10.0.0.0/24"
    error_message = "Rule 50 on the data NACL must deny the web tier before any permit."
  }

  assert {
    condition     = aws_network_acl_rule.this["data-in-100"].rule_action == "allow" && aws_network_acl_rule.this["data-in-100"].from_port == 5432
    error_message = "Rule 100 on the data NACL must permit PostgreSQL from the app tier."
  }
}

run "data_tier_cannot_reach_the_internet" {
  command = plan

  assert {
    condition = alltrue([
      for k, r in aws_network_acl_rule.this :
      r.cidr_block != "0.0.0.0/0" if startswith(k, "data-")
    ])
    error_message = "No data-tier NACL rule may reference 0.0.0.0/0."
  }
}

run "app_https_rules_follow_s3_toggle" {
  command = plan

  variables {
    enable_s3_access  = true
    s3_prefix_list_id = "pl-63a5400a"
  }

  assert {
    condition     = length(aws_vpc_security_group_egress_rule.app_to_s3) == 1 && aws_network_acl_rule.this["app-out-300"].from_port == 443
    error_message = "Enabling S3 access should add an SG egress rule and NACL rule 300."
  }
}

run "no_app_internet_rules_by_default" {
  command = plan

  assert {
    condition     = !contains(keys(aws_network_acl_rule.this), "app-out-300")
    error_message = "App tier should have no internet-bound NACL rules unless enabled."
  }
}
