# Security Policy

## Reporting a vulnerability

This is a personal learning and portfolio project. If you find a security
issue (for example, a rule that is more permissive than documented, or an
accidentally committed secret), please open a
[private security advisory](../../security/advisories/new) instead of a public issue.

## Controls in this repository

| Control | How it's enforced |
|---|---|
| No secrets in git | `.gitignore` blocks state, `*.tfvars`, keys, and `.env`; `gitleaks` runs in pre-commit and in CI over the full history; GitHub push protection is on |
| No cloud keys in code | Providers read credentials only from the AWS CLI profile or environment |
| IaC misconfiguration scanning | Checkov runs on every push and pull request; results go to GitHub code scanning |
| Every exception is documented | Each Checkov skip sits inline next to the resource with a written reason |
| Least privilege | The flow log IAM role can write to one log group only, with a confused deputy guard |
| Dependency hygiene | Provider versions are pinned in `.terraform.lock.hcl`; Dependabot watches Actions and providers |
