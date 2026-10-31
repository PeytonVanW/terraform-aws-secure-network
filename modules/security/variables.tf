variable "name" {
  description = "Name prefix applied to every resource."
  type        = string
}

variable "vpc_id" {
  description = "VPC to create security groups and NACLs in."
  type        = string
}

variable "subnet_ids_by_tier" {
  description = "Map of tier (public, app, data) to subnet IDs. Output of the vpc module."
  type        = map(list(string))

  validation {
    condition     = alltrue([for t in ["public", "app", "data"] : contains(keys(var.subnet_ids_by_tier), t)])
    error_message = "subnet_ids_by_tier must contain public, app, and data keys."
  }
}

variable "subnet_cidrs_by_tier" {
  description = "Map of tier (public, app, data) to subnet CIDRs. Output of the vpc module."
  type        = map(list(string))

  validation {
    condition     = alltrue([for t in ["public", "app", "data"] : contains(keys(var.subnet_cidrs_by_tier), t)])
    error_message = "subnet_cidrs_by_tier must contain public, app, and data keys."
  }
}

variable "app_port" {
  description = "TCP port the app tier listens on (web tier -> app tier)."
  type        = number
  default     = 8080

  validation {
    condition     = var.app_port >= 1 && var.app_port <= 65535
    error_message = "app_port must be a valid TCP port."
  }
}

variable "db_port" {
  description = "TCP port the data tier listens on (app tier -> data tier). 5432 = PostgreSQL."
  type        = number
  default     = 5432

  validation {
    condition     = var.db_port >= 1 && var.db_port <= 65535
    error_message = "db_port must be a valid TCP port."
  }
}

variable "admin_cidrs" {
  description = "CIDRs allowed to SSH into the web tier (e.g. your home IP as x.x.x.x/32). Empty = no SSH at all."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for c in var.admin_cidrs : can(cidrhost(c, 0))])
    error_message = "Every admin_cidrs entry must be a valid CIDR."
  }
}

variable "enable_s3_access" {
  description = "Allow the app tier to reach S3 over HTTPS through the gateway endpoint."
  type        = bool
  default     = false
}

variable "s3_prefix_list_id" {
  description = "Prefix list ID of the S3 gateway endpoint. Required when enable_s3_access = true."
  type        = string
  default     = null
}

variable "allow_app_internet_https" {
  description = "Allow the app tier outbound HTTPS to the internet. Only useful with a NAT gateway."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Extra tags merged onto every resource."
  type        = map(string)
  default     = {}
}
