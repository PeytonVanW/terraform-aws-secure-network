# -----------------------------------------------------------------------------
# Security groups: STATEFUL, attached to network interfaces.
#
# Design: "security group chaining". Each tier only accepts traffic from the
# security group of the tier directly in front of it, never from raw CIDRs.
#
#   internet --443--> web-sg --app_port--> app-sg --db_port--> db-sg
#
# Because security groups are stateful, return traffic is allowed
# automatically (like a Cisco reflexive ACL or a stateful firewall).
# -----------------------------------------------------------------------------

locals {
  common_tags = merge(var.tags, { Module = "security" })
}

resource "aws_security_group" "web" {
  # checkov:skip=CKV2_AWS_5:Network-only module; compute (EC2/ALB/RDS) attaches to these groups in a later project.
  name        = "${var.name}-web-sg"
  description = "Web tier: HTTPS from the internet, optional SSH from admin IPs"
  vpc_id      = var.vpc_id
  tags        = merge(local.common_tags, { Name = "${var.name}-web-sg", Tier = "public" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "app" {
  # checkov:skip=CKV2_AWS_5:Network-only module; compute (EC2/ALB/RDS) attaches to these groups in a later project.
  name        = "${var.name}-app-sg"
  description = "App tier: only accepts traffic from the web tier security group"
  vpc_id      = var.vpc_id
  tags        = merge(local.common_tags, { Name = "${var.name}-app-sg", Tier = "app" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "db" {
  # checkov:skip=CKV2_AWS_5:Network-only module; compute (EC2/ALB/RDS) attaches to these groups in a later project.
  name        = "${var.name}-db-sg"
  description = "Data tier: only accepts traffic from the app tier security group"
  vpc_id      = var.vpc_id
  tags        = merge(local.common_tags, { Name = "${var.name}-db-sg", Tier = "data" })

  lifecycle {
    create_before_destroy = true
  }
}

# ----------------------------- web tier --------------------------------------

resource "aws_vpc_security_group_ingress_rule" "web_https" {
  security_group_id = aws_security_group.web.id
  description       = "HTTPS from anywhere"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "web_ssh_admin" {
  for_each = toset(var.admin_cidrs)

  security_group_id = aws_security_group.web.id
  description       = "SSH from admin ${each.value}"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = each.value
}

resource "aws_vpc_security_group_egress_rule" "web_to_app" {
  security_group_id            = aws_security_group.web.id
  description                  = "Web tier to app tier on the app port"
  ip_protocol                  = "tcp"
  from_port                    = var.app_port
  to_port                      = var.app_port
  referenced_security_group_id = aws_security_group.app.id
}

resource "aws_vpc_security_group_egress_rule" "web_https_out" {
  security_group_id = aws_security_group.web.id
  description       = "Outbound HTTPS for OS and package updates"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

# ----------------------------- app tier --------------------------------------

resource "aws_vpc_security_group_ingress_rule" "app_from_web" {
  security_group_id            = aws_security_group.app.id
  description                  = "App port from the web tier only"
  ip_protocol                  = "tcp"
  from_port                    = var.app_port
  to_port                      = var.app_port
  referenced_security_group_id = aws_security_group.web.id
}

resource "aws_vpc_security_group_egress_rule" "app_to_db" {
  security_group_id            = aws_security_group.app.id
  description                  = "App tier to data tier on the database port"
  ip_protocol                  = "tcp"
  from_port                    = var.db_port
  to_port                      = var.db_port
  referenced_security_group_id = aws_security_group.db.id
}

resource "aws_vpc_security_group_egress_rule" "app_to_s3" {
  count = var.enable_s3_access ? 1 : 0

  security_group_id = aws_security_group.app.id
  description       = "HTTPS to S3 via the gateway endpoint prefix list only"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  prefix_list_id    = var.s3_prefix_list_id

  lifecycle {
    precondition {
      condition     = var.s3_prefix_list_id != null
      error_message = "enable_s3_access = true requires s3_prefix_list_id."
    }
  }
}

resource "aws_vpc_security_group_egress_rule" "app_https_internet" {
  count = var.allow_app_internet_https ? 1 : 0

  security_group_id = aws_security_group.app.id
  description       = "Outbound HTTPS to the internet through the NAT gateway"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

# ----------------------------- data tier -------------------------------------

resource "aws_vpc_security_group_ingress_rule" "db_from_app" {
  security_group_id            = aws_security_group.db.id
  description                  = "Database port from the app tier only"
  ip_protocol                  = "tcp"
  from_port                    = var.db_port
  to_port                      = var.db_port
  referenced_security_group_id = aws_security_group.app.id
}

# The data tier has NO egress rules on purpose. Security groups are stateful,
# so replies to the app tier still flow, but the database can never start a
# new outbound connection (blocks data exfiltration and callbacks).
