# Security Design

## Threat model (lab scope)

| Threat | Control in this repo |
|---|---|
| Internet attacker scans the network | Only TCP 443 is reachable, and only on the web tier. SSH is off unless you give an admin /32. |
| Compromised web server pivots to the database | NACL rule 50 denies web → data at the subnet edge, and the db-sg accepts only app-sg. Two independent controls must both fail. |
| Compromised database exfiltrates data | Data tier has no default route, no SG egress rules, and no NACL rule to `0.0.0.0/0`. A unit test enforces it. |
| App tier calls out to attacker infrastructure | App tier has no internet route (NAT off), and SG egress on 443 is limited to the S3 prefix list. |
| Someone launches an instance into the default SG | Default SG has zero rules (CIS AWS Foundations 5.4). |
| Accidental public IP exposure | `map_public_ip_on_launch = false` on every subnet, verified by a test. |
| Undetected policy violations | VPC Flow Logs record ACCEPT and REJECT for every ENI. |
| Leaked cloud credentials | No keys in code. Gitleaks runs in pre-commit and CI over full history. `.gitignore` blocks tfvars, state, and keys. CI uses no cloud credentials at all. |
| Misconfiguration slips in through a pull request | Checkov and unit tests run on every PR. |

## Layered enforcement

```
packet from web → data
   │
   ├─ 1. web-sg egress:     only allows app_port → app-sg     ✗ blocked
   ├─ 2. public NACL out:   no rule for data CIDRs            ✗ blocked
   ├─ 3. data NACL in:      rule 50 DENY from web CIDRs       ✗ blocked
   └─ 4. db-sg ingress:     only allows from app-sg           ✗ blocked
```

So the web tier is blocked from the database in four separate places, and all four would have to fail.

## Documented exceptions (Checkov skips)

Each skip is inline in the code next to the resource it affects.

| Check | Resource | Justification |
|---|---|---|
| CKV_AWS_158 (KMS on log group) | flow-logs log group | A customer-managed KMS key costs about $1/month. The log group still uses AWS-managed encryption at rest. Enable KMS for production. |
| CKV_AWS_338 (1-year retention) | flow-logs log group | Lab uses 7-day retention to stay free. Production would keep logs for 1 year or more for compliance. |
| CKV2_AWS_11 (VPC flow logs) | `aws_vpc` | Flow logs exist in a separate module. Checkov's graph can't follow cross-module references. |
| CKV2_AWS_1 (NACL attached) | `aws_network_acl` | NACLs are attached through `subnet_ids` from the vpc module. Same graph limitation. |
| CKV2_AWS_5 (SG attached) | security groups | This is a network-only module. Compute attaches in the roadmap's EC2/ALB project. |

## What I'd add for production
- Customer-managed KMS keys for logs, plus a 1-year retention policy
- A CloudWatch metric filter and alarm on REJECT spikes
- Remote state in an encrypted, versioned S3 bucket with state locking
- OIDC-based GitHub Actions role (no long-lived keys) for `plan` on pull requests
- AWS Config rules / Security Hub for continuous compliance
- Interface endpoints (SSM) instead of SSH, which removes port 22 entirely
