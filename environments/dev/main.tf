locals {
  name = var.project_name

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Owner       = var.owner
  }

  app_bucket_name = coalesce(var.app_bucket_name, "${var.project_name}-${var.environment}-app")
}

# -- Networking --------------------------------------------------------------

module "vpc" {
  source = "../../modules/vpc"

  name               = local.name
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones

  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs

  tags = local.tags
}

# -- Application S3 bucket ---------------------------------------------------

module "app_bucket" {
  source = "../../modules/s3"

  bucket_name                          = local.app_bucket_name
  force_destroy                        = var.app_bucket_force_destroy
  enable_lifecycle                     = true
  lifecycle_glacier_transition_days    = var.app_bucket_glacier_transition_days
  lifecycle_noncurrent_expiration_days = var.app_bucket_noncurrent_expiration_days

  tags = local.tags
}

# -- IAM roles (EC2 + GitHub Actions) ----------------------------------------

module "iam" {
  source = "../../modules/iam"

  name = local.name

  s3_bucket_arn    = module.app_bucket.bucket_arn
  cw_log_group_arns = [
    "arn:aws:logs:${var.aws_region}:*:log-group:/aws/${local.name}/*",
  ]

  github_org      = var.github_org
  github_repo     = var.github_repo
  github_branches = var.github_branches

  create_oidc_provider = var.create_github_oidc_provider
  oidc_provider_arn    = var.oidc_provider_arn

  tags = local.tags
}

# -- EC2 instance ------------------------------------------------------------

module "ec2" {
  source = "../../modules/ec2"

  name      = "${local.name}-app"
  vpc_id    = module.vpc.vpc_id
  subnet_id = module.vpc.public_subnet_ids[0]

  instance_type               = var.ec2_instance_type
  key_pair_name               = var.ec2_key_pair_name
  iam_instance_profile_name   = module.iam.ec2_instance_profile_name
  ssh_cidr_blocks             = var.ec2_ssh_cidr_blocks
  ingress_cidr_blocks         = var.ec2_ingress_cidr_blocks
  root_volume_size_gb         = var.ec2_root_volume_size_gb
  associate_public_ip         = true

  tags = local.tags
}

# -- CloudWatch monitoring ---------------------------------------------------

module "monitoring" {
  source = "../../modules/monitoring"

  name                        = local.name
  alert_email                 = var.alert_email
  ec2_instance_id             = module.ec2.instance_id
  billing_alarm_threshold_usd = var.billing_alarm_threshold_usd
  log_group_retention_days    = var.log_group_retention_days

  tags = local.tags
}