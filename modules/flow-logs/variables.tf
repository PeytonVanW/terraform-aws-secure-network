variable "name" {
  description = "Name prefix applied to every resource."
  type        = string
}

variable "vpc_id" {
  description = "VPC to capture flow logs for."
  type        = string
}

variable "traffic_type" {
  description = "Which traffic to log: ACCEPT, REJECT, or ALL."
  type        = string
  default     = "ALL"

  validation {
    condition     = contains(["ACCEPT", "REJECT", "ALL"], var.traffic_type)
    error_message = "traffic_type must be ACCEPT, REJECT, or ALL."
  }
}

variable "retention_in_days" {
  description = "How long CloudWatch keeps flow logs. Short retention keeps costs at $0 for a lab."
  type        = number
  default     = 7

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365], var.retention_in_days)
    error_message = "retention_in_days must be a value CloudWatch supports (1, 3, 5, 7, 14, 30, 60, 90, ...)."
  }
}

variable "tags" {
  description = "Extra tags merged onto every resource."
  type        = map(string)
  default     = {}
}
