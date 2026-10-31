output "security_group_ids" {
  description = "Map of tier to security group ID."
  value = {
    web = aws_security_group.web.id
    app = aws_security_group.app.id
    db  = aws_security_group.db.id
  }
}

output "network_acl_ids" {
  description = "Map of tier to network ACL ID."
  value       = { for tier, acl in aws_network_acl.tier : tier => acl.id }
}

output "nacl_rule_table" {
  description = "The full NACL policy as a readable table (tier/direction/rule -> action, protocol, ports, CIDR)."
  value = {
    for k, r in local.nacl_rules_by_key :
    k => "${r.action} ${r.protocol == "-1" ? "all" : r.protocol} ${r.cidr} ports ${r.from}-${r.to}"
  }
}
