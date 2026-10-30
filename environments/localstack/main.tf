# Root module for the LocalStack environment: wires the three modules together.
# Run from this directory with:  make local-up && make local-apply

module "vpc" {
  source = "../../modules/vpc"

  name               = var.name
  region             = var.region
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
}
