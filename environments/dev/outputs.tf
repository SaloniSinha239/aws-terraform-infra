output "vpc_id" {
  description = "ID of the VPC."
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC."
  value       = module.vpc.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets (one per AZ)."
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets (one per AZ)."
  value       = module.vpc.private_subnet_ids
}

output "ec2_instance_id" {
  description = "ID of the EC2 instance."
  value       = module.ec2.instance_id
}

output "ec2_public_ip" {
  description = "Public IP address of the EC2 instance."
  value       = module.ec2.instance_public_ip
}

output "ec2_private_ip" {
  description = "Private IP address of the EC2 instance."
  value       = module.ec2.instance_private_ip
}

output "ec2_security_group_id" {
  description = "ID of the EC2 security group."
  value       = module.ec2.security_group_id
}

output "ec2_ami_id" {
  description = "ID of the Amazon Linux 2023 AMI used."
  value       = module.ec2.ami_id
}

output "app_bucket_name" {
  description = "Name of the application S3 bucket."
  value       = module.app_bucket.bucket_id
}

output "app_bucket_arn" {
  description = "ARN of the application S3 bucket."
  value       = module.app_bucket.bucket_arn
}

output "app_bucket_domain_name" {
  description = "Regional domain name of the application S3 bucket."
  value       = module.app_bucket.bucket_domain_name
}

output "ec2_iam_role_arn" {
  description = "ARN of the EC2 IAM role."
  value       = module.iam.ec2_role_arn
}

output "ec2_instance_profile_name" {
  description = "Name of the EC2 IAM instance profile."
  value       = module.iam.ec2_instance_profile_name
}

output "github_actions_role_arn" {
  description = "ARN of the IAM role GitHub Actions assumes via OIDC."
  value       = module.iam.github_actions_role_arn
}

output "github_oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider."
  value       = module.iam.github_oidc_provider_arn
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic that receives CloudWatch alarm notifications."
  value       = module.monitoring.sns_topic_arn
}

output "cloudwatch_log_group_name" {
  description = "Name of the application CloudWatch Log Group."
  value       = module.monitoring.log_group_name
}