# Run `make help` to list every target. On Windows, run these inside WSL2 (Ubuntu).

SHELL := /bin/bash
LOCAL_DIR := environments/localstack
AWS_DIR   := environments/aws
MODULES   := $(wildcard modules/*)

# LocalStack accepts any credentials. Setting dummy ones here keeps fake keys
# out of the Terraform code, so secret scanners have nothing to flag.
LOCAL_ENV := AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_REGION=us-east-1

.PHONY: help fmt validate lint test scan secrets check \
        local-up local-down local-plan local-apply local-destroy local-verify \
        aws-plan aws-apply aws-destroy

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

# Quality gates: the same checks CI runs, so problems show up before a push.
fmt: ## Format all Terraform files
	terraform fmt -recursive

validate: ## terraform validate every environment
	@for d in environments/*/; do \
		echo "== $$d"; \
		terraform -chdir=$$d init -backend=false -input=false >/dev/null && terraform -chdir=$$d validate || exit 1; \
	done

lint: ## Run TFLint
	tflint --init --config=$(CURDIR)/.tflint.hcl
	tflint --recursive --config=$(CURDIR)/.tflint.hcl

test: ## Run unit tests (mocked AWS - no account needed)
	@for d in $(MODULES); do \
		echo "== $$d"; \
		terraform -chdir=$$d init -backend=false -input=false >/dev/null && terraform -chdir=$$d test || exit 1; \
	done

scan: ## Security scan with Checkov
	checkov -d . --framework terraform --compact --quiet

secrets: ## Scan the full git history for leaked secrets
	gitleaks git --verbose

check: fmt validate test scan secrets ## Run everything CI runs

# LocalStack: the full lab on this machine for $0.
local-up: ## Start LocalStack (needs LOCALSTACK_AUTH_TOKEN exported)
	docker compose up -d
	@echo "Waiting for LocalStack..." && until curl -sf localhost:4566/_localstack/health >/dev/null; do sleep 2; done && echo "Ready."

local-down: ## Stop LocalStack
	docker compose down

local-plan: ## Plan against LocalStack
	cd $(LOCAL_DIR) && terraform init -input=false && $(LOCAL_ENV) terraform plan

local-apply: ## Apply against LocalStack
	cd $(LOCAL_DIR) && terraform init -input=false && $(LOCAL_ENV) terraform apply

local-destroy: ## Destroy LocalStack resources
	cd $(LOCAL_DIR) && $(LOCAL_ENV) terraform destroy

local-verify: ## Inspect what was built using the AWS CLI against LocalStack
	@$(LOCAL_ENV) aws --endpoint-url=http://localhost:4566 ec2 describe-subnets \
		--query 'Subnets[].{Name:Tags[?Key==`Name`]|[0].Value,CIDR:CidrBlock,AZ:AvailabilityZone}' --output table
	@$(LOCAL_ENV) aws --endpoint-url=http://localhost:4566 ec2 describe-network-acls \
		--query 'NetworkAcls[].{Name:Tags[?Key==`Name`]|[0].Value,Rules:length(Entries)}' --output table

# Real AWS: credentials come from AWS_PROFILE. Always destroy when you're done.
aws-plan: ## Plan against real AWS (uses your AWS_PROFILE)
	cd $(AWS_DIR) && terraform init -input=false && terraform plan

aws-apply: ## Apply to real AWS - remember to destroy!
	cd $(AWS_DIR) && terraform init -input=false && terraform apply

aws-destroy: ## Tear everything down in real AWS
	cd $(AWS_DIR) && terraform destroy
