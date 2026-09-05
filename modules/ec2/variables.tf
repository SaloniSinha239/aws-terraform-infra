variable "name" {
  description = "Name prefix for EC2 resources."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the instance and security group live."
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID to launch the instance in (typically a public subnet)."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.micro"
}

variable "key_pair_name" {
  description = "Name of the EC2 Key Pair to associate with the instance. The private key must already exist outside Terraform."
  type        = string
  default     = null
}

variable "iam_instance_profile_name" {
  description = "Name of the IAM instance profile to attach."
  type        = string
}

variable "ssh_cidr_blocks" {
  description = "CIDR blocks allowed to reach SSH (port 22) on the instance. Restrict to known IPs (e.g. your office / VPN)."
  type        = list(string)
  default     = ["0.0.0.0/0"] # explicit default; callers MUST narrow in tfvars

  validation {
    condition     = !contains(var.ssh_cidr_blocks, "0.0.0.0/0") || length(var.ssh_cidr_blocks) == 1
    error_message = "0.0.0.0/0 is the most permissive SSH source; supply your own CIDR(s) in terraform.tfvars."
  }
}

variable "ingress_cidr_blocks" {
  description = "CIDR blocks for HTTP/HTTPS ingress on ports 80 and 443. Defaults to the whole internet; restrict as needed."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "root_volume_size_gb" {
  description = "Root EBS volume size in GiB."
  type        = number
  default     = 20
}

variable "user_data" {
  description = "Optional user_data script (plain text). For binary, use user_data_base64."
  type        = string
  default     = null
}

variable "user_data_base64" {
  description = "Optional base64-encoded user_data."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to EC2 resources."
  type        = map(string)
  default     = {}
}

variable "associate_public_ip" {
  description = "Whether to associate a public IP with the instance. Should be true only for public-subnet workloads."
  type        = bool
  default     = true
}