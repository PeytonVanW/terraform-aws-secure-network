variable "region" {
  description = "Region LocalStack emulates."
  type        = string
  default     = "us-east-1"
}

variable "localstack_endpoint" {
  description = "LocalStack edge endpoint."
  type        = string
  default     = "http://localhost:4566"
}

variable "name" {
  description = "Name prefix for all resources."
  type        = string
  default     = "lab"
}

variable "vpc_cidr" {
  description = "VPC CIDR block."
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "AZs to deploy into."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "admin_cidrs" {
  description = "CIDRs allowed to SSH to the web tier. Leave empty to disable SSH."
  type        = list(string)
  default     = []
}
