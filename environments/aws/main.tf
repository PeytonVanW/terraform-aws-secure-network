# Root module for a real AWS account. The defaults cost $0: VPCs, subnets,
# route tables, internet gateways, security groups, NACLs, and S3 gateway
# endpoints have no hourly charge, and nothing gets a public IPv4 address
# unless the NAT gateway is turned on.
#
# Run `terraform destroy` at the end of every session so nothing is left
# running between labs.

module "vpc" {
  source = "../../modules/vpc"

  name               = var.name
  region             = var.region
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones

  enable_nat_gateway         = var.enable_nat_gateway
  enable_s3_gateway_endpoint = true # free, and S3 traffic stays off the internet
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

  # The app tier only gets outbound HTTPS when a NAT gateway exists to carry it.
  allow_app_internet_https = var.enable_nat_gateway
}

module "flow_logs" {
  source = "../../modules/flow-logs"
  count  = var.enable_flow_logs ? 1 : 0

  name   = var.name
  vpc_id = module.vpc.vpc_id
}
