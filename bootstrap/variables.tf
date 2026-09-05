variable "project_name" {
  description = "Project name used as a prefix for the state bucket and lock table."
  type        = string
}

variable "aws_region" {
  description = "Region for the state bucket (must match where the main stack runs)."
  type        = string
  default     = "us-east-1"
}

variable "tags" {
  description = "Tags applied to bootstrap resources."
  type        = map(string)
  default     = {}
}

variable "force_destroy" {
  description = "Allow Terraform to delete a non-empty state bucket (use only when intentionally retiring the environment)."
  type        = bool
  default     = false
}