# Cost Safety: Keeping This at $0

## What's free with the default settings

| Resource | Hourly cost |
|---|---|
| VPC, subnets, route tables, routes | Free |
| Internet gateway | Free |
| Security groups, network ACLs | Free |
| S3 gateway endpoint | Free |
| AWS Budgets (first two budgets) | Free |

## What costs money (all OFF by default)

| Resource | Variable | Why it's off |
|---|---|---|
| NAT gateway | `enable_nat_gateway` | Billed per hour and per GB processed, even when idle |
| Public IPv4 / Elastic IP | (created only with NAT) | AWS bills every public IPv4 address hourly |
| VPC Flow Logs → CloudWatch | `enable_flow_logs` (aws env) | Log ingestion and storage are billed past the free allowance. Tiny for a lab, but opt-in. |
| Interface endpoints | not used | Billed per hour per AZ. The gateway endpoint is used instead. |

## Guardrails
1. Budget alarm in code: set `budget_alert_email` and Terraform creates a $1/month budget. It emails you at 50% actual spend and at 100% forecasted.
2. Default to LocalStack: iterate locally, and deploy to real AWS only to prove it works.
3. Destroy the same day: `make aws-destroy`. Check the Billing console the next day.
4. Account hygiene: turn on MFA for the root user, never use root access keys, and create an IAM Identity Center (SSO) user for daily work.

> Note: AWS changed its free tier for new accounts in July 2025. New accounts
> get a credit-based free plan instead of the old 12-month model. Check the
> current terms on the AWS Free Tier page before deploying anything outside
> this repo.
