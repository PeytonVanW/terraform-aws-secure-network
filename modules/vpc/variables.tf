variable "name" {
  description = "Name prefix applied to every resource (e.g. \"lab\")."
  type        = string
}

variable "region" {
  description = "AWS region. Used to build the S3 gateway endpoint service name."
  type        = string
}

variable "vpc_cidr" {
  description = "IPv4 CIDR block for the VPC. Must be RFC 1918 private space."
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_newbits" {
  description = "Bits added to the VPC prefix for each subnet. /16 + 8 = /24 subnets (254 hosts, 251 usable in AWS)."
  type        = number
  default     = 8
}

variable "availability_zones" {
  description = "AZs to spread subnets across. One subnet per tier per AZ."
  type        = list(string)
}

variable "tags" {
  description = "Extra tags merged onto every resource."
  type        = map(string)
  default     = {}
}
