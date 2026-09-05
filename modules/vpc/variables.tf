variable "name" {
  description = "Name prefix for all VPC resources."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid IPv4 CIDR (e.g. 10.0.0.0/16)."
  }
}

variable "availability_zones" {
  description = "List of Availability Zones to spread subnets across (exactly 2 expected for HA)."
  type        = list(string)
  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "Provide at least 2 AZs so subnets can be distributed for HA."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets, one per AZ in order."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets, one per AZ in order."
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "tags" {
  description = "Tags to apply to all VPC resources."
  type        = map(string)
  default     = {}
}