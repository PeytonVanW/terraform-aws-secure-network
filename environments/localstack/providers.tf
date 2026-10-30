terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # State stays on your machine for the LocalStack lab. *.tfstate is
  # git-ignored - never commit it.
}

# Points the AWS provider at LocalStack instead of real AWS.
# Credentials come from environment variables set by the Makefile
# (AWS_ACCESS_KEY_ID=test / AWS_SECRET_ACCESS_KEY=test). LocalStack accepts
# any value, and keeping them out of code means scanners never see "keys".
provider "aws" {
  region = var.region

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    ec2  = var.localstack_endpoint
    iam  = var.localstack_endpoint
    logs = var.localstack_endpoint
    s3   = var.localstack_endpoint
    sts  = var.localstack_endpoint
  }

  default_tags {
    tags = {
      Project     = "terraform-aws-secure-network"
      Environment = "localstack"
      ManagedBy   = "terraform"
    }
  }
}
