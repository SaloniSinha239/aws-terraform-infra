variable "aws_region" {
  description = "AWS region to deploy the dev environment into."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name used for tagging (e.g. dev, staging, prod)."
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Short project name used as a prefix for all resource names and tags."
  type        = string
  default     = "aws-iac-portfolio"
}

variable "owner" {
  description = "Owner tag value (email or team name)."
  type        = string
  default     = "platform-team@example.com"
}

# -- VPC ----------------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Two Availability Zones to spread public/private subnets across for HA."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets, one per AZ."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets, one per AZ."
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

# -- EC2 ----------------------------------------------------------------------

variable "ec2_instance_type" {
  description = "EC2 instance type for the dev workload."
  type        = string
  default     = "t3.micro"
}

variable "ec2_key_pair_name" {
  description = "Name of an existing EC2 Key Pair in the target region. The private key is NOT created or stored by Terraform."
  type        = string
  default     = null
}

variable "ec2_ssh_cidr_blocks" {
  description = "CIDR blocks allowed to SSH to the EC2 instance (port 22). MUST be narrowed in terraform.tfvars away from 0.0.0.0/0."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "ec2_ingress_cidr_blocks" {
  description = "CIDR blocks allowed to reach HTTP/HTTPS on the EC2 instance."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "ec2_root_volume_size_gb" {
  description = "Root EBS volume size in GiB."
  type        = number
  default     = 20
}

# -- S3 (application bucket) -------------------------------------------------

variable "app_bucket_name" {
  description = "Globally-unique name for the application S3 bucket. Leave empty to derive one from project_name + random suffix (not implemented here — supply explicitly)."
  type        = string
  default     = null
}

variable "app_bucket_force_destroy" {
  description = "Allow Terraform to delete a non-empty app bucket. Only set true for dev."
  type        = bool
  default     = false
}

variable "app_bucket_glacier_transition_days" {
  description = "Days after creation to transition objects to Glacier."
  type        = number
  default     = 90
}

variable "app_bucket_noncurrent_expiration_days" {
  description = "Days after which noncurrent object versions expire."
  type        = number
  default     = 365
}

# -- Monitoring ---------------------------------------------------------------

variable "alert_email" {
  description = "Email address that receives CloudWatch alarm notifications. Confirmation is required from the inbox on first use."
  type        = string
}

variable "billing_alarm_threshold_usd" {
  description = "Estimated monthly charges (USD) that trip the billing alarm. The AWS/Billing metric is published only in us-east-1."
  type        = number
  default     = 25
}

variable "log_group_retention_days" {
  description = "Retention period (days) for the application CloudWatch Log Group."
  type        = number
  default     = 30
}

# -- GitHub Actions OIDC ------------------------------------------------------

variable "github_org" {
  description = "GitHub organization/user that owns the repository allowed to assume the deploy role."
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name allowed to assume the deploy role."
  type        = string
}

variable "github_branches" {
  description = "Git refs (branch names) allowed to assume the deploy role via OIDC. Default: main only."
  type        = list(string)
  default     = ["main"]
}

variable "create_github_oidc_provider" {
  description = "Set true to create the GitHub OIDC provider in this stack. Set false if it already exists in the account (then supply oidc_provider_arn)."
  type        = bool
  default     = true
}

variable "oidc_provider_arn" {
  description = "Existing GitHub OIDC provider ARN. Used only when create_github_oidc_provider is false."
  type        = string
  default     = ""
}