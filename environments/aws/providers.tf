terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # State stays local for this lab. For shared use, move it to an S3 bucket
  # with versioning (to roll back a bad state) and encryption (state can hold
  # secrets). use_lockfile gives native S3 locking on Terraform 1.10+, so two
  # applies can't run at once and no DynamoDB table is needed.
  #
  # backend "s3" {
  #   bucket       = "YOUR-UNIQUE-STATE-BUCKET"
  #   key          = "secure-network/aws/terraform.tfstate"
  #   region       = "us-east-1"
  #   encrypt      = true
  #   use_lockfile = true
  # }
}

# No credentials in code. The provider reads them from the AWS CLI profile, so
# nothing secret can end up in git. SSO is recommended because its
# credentials are short-lived.
#   aws configure sso          (recommended)  or  aws configure --profile lab
#   export AWS_PROFILE=lab
provider "aws" {
  region = var.region

  # Every resource gets these tags, so billing reports and cleanup can find
  # everything Terraform created.
  default_tags {
    tags = {
      Project     = "terraform-aws-secure-network"
      Environment = "aws-lab"
      ManagedBy   = "terraform"
    }
  }
}
