variable "name" {
  description = "Name prefix applied to every resource (e.g. \"lab\")."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{2,24}$", var.name))
    error_message = "name must be 2-24 characters: lowercase letters, numbers, and hyphens."
  }
}

variable "region" {
  description = "AWS region. Used to build the S3 gateway endpoint service name."
  type        = string
}

variable "vpc_cidr" {
  description = "IPv4 CIDR block for the VPC. Must be RFC 1918 private space."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR, e.g. 10.0.0.0/16."
  }

  validation {
    condition = can(cidrhost(var.vpc_cidr, 0)) && anytrue([
      startswith(var.vpc_cidr, "10."),
      can(regex("^172\\.(1[6-9]|2[0-9]|3[01])\\.", var.vpc_cidr)),
      startswith(var.vpc_cidr, "192.168."),
    ])
    error_message = "vpc_cidr must be in RFC 1918 private space (10/8, 172.16/12, 192.168/16)."
  }
}

variable "subnet_newbits" {
  description = "Bits added to the VPC prefix for each subnet. /16 + 8 = /24 subnets (254 hosts, 251 usable in AWS)."
  type        = number
  default     = 8

  validation {
    condition     = var.subnet_newbits >= 4 && var.subnet_newbits <= 12
    error_message = "subnet_newbits must be between 4 and 12."
  }
}

variable "availability_zones" {
  description = "AZs to spread subnets across. One subnet per tier per AZ."
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) >= 2 && length(var.availability_zones) <= 3
    error_message = "Use 2 or 3 availability zones for high availability."
  }

  validation {
    condition     = length(distinct(var.availability_zones)) == length(var.availability_zones)
    error_message = "availability_zones must not contain duplicates."
  }
}

variable "tags" {
  description = "Extra tags merged onto every resource."
  type        = map(string)
  default     = {}
}
