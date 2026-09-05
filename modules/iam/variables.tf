variable "name" {
  description = "Name prefix for IAM resources."
  type        = string
}

variable "tags" {
  description = "Tags applied to all IAM resources."
  type        = map(string)
  default     = {}
}

variable "s3_bucket_arn" {
  description = "ARN of the application S3 bucket the EC2 instance role can read from. Leave empty to skip S3 permissions."
  type        = string
  default     = ""
}

variable "cw_log_group_arns" {
  description = "CloudWatch Log Group ARNs the EC2 instance role can write to (e.g. for the CloudWatch agent). Empty list = no log group perms."
  type        = list(string)
  default     = []
}

variable "github_org" {
  description = "GitHub organization/user that owns the repository allowed to assume the GitHub Actions role."
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name allowed to assume the GitHub Actions role."
  type        = string
}

variable "github_branches" {
  description = "Branches allowed to assume the GitHub Actions role. Use ['*'] to allow all branches (not advised)."
  type        = list(string)
  default     = ["main"]
}

variable "oidc_provider_arn" {
  description = "ARN of the IAM OIDC identity provider for token.actions.githubusercontent.com. If empty, the provider is created here."
  type        = string
  default     = ""
}

variable "create_oidc_provider" {
  description = "Set true to create the GitHub OIDC provider in this module (one-time, per account)."
  type        = bool
  default     = true
}