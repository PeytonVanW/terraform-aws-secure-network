# -----------------------------------------------------------------------------
# Network ACLs: STATELESS, attached to subnets. The closest AWS equivalent of
# a Cisco extended ACL applied to an interface.
#
#   * Rules are evaluated lowest rule_number first; first match wins
#     (same as IOS sequence numbers).
#   * Anything not matched hits the implicit "*" deny (same as IOS's
#     implicit "deny any any" at the end of every ACL).
#   * Stateless means return traffic must be allowed explicitly, which is
#     why you see ephemeral port ranges (1024-65535) below.
#
# Every rule lives in one table (local.nacl_rules) so the policy reads like an
# access-list. docs/ccna-to-aws.md shows the equivalent IOS configuration.
# -----------------------------------------------------------------------------

locals {
  public_cidrs = var.subnet_cidrs_by_tier["public"]
  app_cidrs    = var.subnet_cidrs_by_tier["app"]
  data_cidrs   = var.subnet_cidrs_by_tier["data"]

  app_needs_https_out = var.enable_s3_access || var.allow_app_internet_https

  ephemeral_from = 1024
  ephemeral_to   = 65535

  nacl_rules = concat(
    # ======================= PUBLIC (web) tier ===============================
    # inbound
    [{ tier = "public", egress = false, rule_number = 100, action = "allow", protocol = "tcp", from = 443, to = 443, cidr = "0.0.0.0/0" }],
    [for i, c in var.admin_cidrs : { tier = "public", egress = false, rule_number = 110 + i, action = "allow", protocol = "tcp", from = 22, to = 22, cidr = c }],
    [{ tier = "public", egress = false, rule_number = 200, action = "allow", protocol = "tcp", from = local.ephemeral_from, to = local.ephemeral_to, cidr = "0.0.0.0/0" }],
    # outbound
    [{ tier = "public", egress = true, rule_number = 100, action = "allow", protocol = "tcp", from = local.ephemeral_from, to = local.ephemeral_to, cidr = "0.0.0.0/0" }],
    [for i, c in local.app_cidrs : { tier = "public", egress = true, rule_number = 110 + i, action = "allow", protocol = "tcp", from = var.app_port, to = var.app_port, cidr = c }],
    [{ tier = "public", egress = true, rule_number = 200, action = "allow", protocol = "tcp", from = 443, to = 443, cidr = "0.0.0.0/0" }],

    # ============================ APP tier ===================================
    # inbound
    [for i, c in local.public_cidrs : { tier = "app", egress = false, rule_number = 100 + i, action = "allow", protocol = "tcp", from = var.app_port, to = var.app_port, cidr = c }],
    [for i, c in local.data_cidrs : { tier = "app", egress = false, rule_number = 200 + i, action = "allow", protocol = "tcp", from = local.ephemeral_from, to = local.ephemeral_to, cidr = c }],
    local.app_needs_https_out ? [{ tier = "app", egress = false, rule_number = 300, action = "allow", protocol = "tcp", from = local.ephemeral_from, to = local.ephemeral_to, cidr = "0.0.0.0/0" }] : [],
    # outbound
    [for i, c in local.public_cidrs : { tier = "app", egress = true, rule_number = 100 + i, action = "allow", protocol = "tcp", from = local.ephemeral_from, to = local.ephemeral_to, cidr = c }],
    [for i, c in local.data_cidrs : { tier = "app", egress = true, rule_number = 200 + i, action = "allow", protocol = "tcp", from = var.db_port, to = var.db_port, cidr = c }],
    local.app_needs_https_out ? [{ tier = "app", egress = true, rule_number = 300, action = "allow", protocol = "tcp", from = 443, to = 443, cidr = "0.0.0.0/0" }] : [],

    # ============================ DATA tier ==================================
    # inbound: explicit DENY from the web tier comes first (lower number),
    # exactly like putting a deny line above the permits in an IOS ACL.
    [for i, c in local.public_cidrs : { tier = "data", egress = false, rule_number = 50 + i, action = "deny", protocol = "-1", from = 0, to = 0, cidr = c }],
    [for i, c in local.app_cidrs : { tier = "data", egress = false, rule_number = 100 + i, action = "allow", protocol = "tcp", from = var.db_port, to = var.db_port, cidr = c }],
    # outbound: replies to the app tier only
    [for i, c in local.app_cidrs : { tier = "data", egress = true, rule_number = 100 + i, action = "allow", protocol = "tcp", from = local.ephemeral_from, to = local.ephemeral_to, cidr = c }],
  )

  nacl_rules_by_key = {
    for r in local.nacl_rules :
    "${r.tier}-${r.egress ? "out" : "in"}-${r.rule_number}" => r
  }
}

resource "aws_network_acl" "tier" {
  # checkov:skip=CKV2_AWS_1:NACLs ARE attached via subnet_ids (input from the vpc module); Checkov cannot resolve cross-module values.
  for_each = toset(["public", "app", "data"])

  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids_by_tier[each.key]

  tags = merge(local.common_tags, { Name = "${var.name}-${each.key}-nacl", Tier = each.key })
}

resource "aws_network_acl_rule" "this" {
  for_each = local.nacl_rules_by_key

  network_acl_id = aws_network_acl.tier[each.value.tier].id
  egress         = each.value.egress
  rule_number    = each.value.rule_number
  rule_action    = each.value.action
  protocol       = each.value.protocol
  from_port      = each.value.from
  to_port        = each.value.to
  cidr_block     = each.value.cidr
}
