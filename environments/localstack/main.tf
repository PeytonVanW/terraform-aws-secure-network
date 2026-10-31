# Root module for the LocalStack environment: wires the three modules together.
# Run from this directory with:  make local-up && make local-apply

module "vpc" {
  source = "../../modules/vpc"

  name               = var.name
  region             = var.region
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones

  enable_nat_gateway         = false
  enable_s3_gateway_endpoint = true
}

module "security" {
  source = "../../modules/security"

  name                 = var.name
  vpc_id               = module.vpc.vpc_id
  subnet_ids_by_tier   = module.vpc.subnet_ids_by_tier
  subnet_cidrs_by_tier = module.vpc.subnet_cidrs_by_tier
  admin_cidrs          = var.admin_cidrs

  enable_s3_access  = true
  s3_prefix_list_id = module.vpc.s3_prefix_list_id
}
