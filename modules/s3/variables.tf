variable "bucket_name" {
  description = "Name of the application S3 bucket. Must be globally unique and DNS-compliant."
  type        = string
}

variable "tags" {
  description = "Tags applied to all S3 resources."
  type        = map(string)
  default     = {}
}

variable "enable_lifecycle" {
  description = "Whether to attach a lifecycle configuration."
  type        = bool
  default     = true
}

variable "lifecycle_glacier_transition_days" {
  description = "Days after object creation to transition to Glacier."
  type        = number
  default     = 90

  validation {
    condition     = var.lifecycle_glacier_transition_days >= 30
    error_message = "Transition to Glacier requires at least 30 days (S3 minimum)."
  }
}

variable "lifecycle_noncurrent_expiration_days" {
  description = "Days after which noncurrent (previous) versions expire."
  type        = number
  default     = 365
}

variable "force_destroy" {
  description = "Allow Terraform to delete a non-empty bucket. Only set true for dev/test."
  type        = bool
  default     = false
}