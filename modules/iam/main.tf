data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "tls_certificate" "github_oidc" {
  count = var.create_oidc_provider ? 1 : 0

  url = "https://token.actions.githubusercontent.com"
}

locals {
  github_oidc_provider_arn = (
    var.create_oidc_provider
    ? aws_iam_openid_connect_provider.github[0].arn
    : var.oidc_provider_arn
  )
}

# -- GitHub OIDC provider -----------------------------------------------------
# Creates the IAM OIDC provider for token.actions.githubusercontent.com.
# The TLS certificate thumbprint is derived from the live cert so it tracks
# GitHub's rotation without manual updates.

resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 1 : 0

  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github_oidc[0].certificates[0].sha1_fingerprint]

  tags = var.tags
}

# -- EC2 instance role -------------------------------------------------------

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2" {
  name               = "${var.name}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json

  tags = var.tags
}

data "aws_iam_policy_document" "ec2_s3_read" {
  count = var.s3_bucket_arn != "" ? 1 : 0

  statement {
    sid    = "ReadAppBucket"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:ListBucket",
    ]

    resources = [
      var.s3_bucket_arn,
      "${var.s3_bucket_arn}/*",
    ]
  }
}

resource "aws_iam_role_policy" "ec2_s3_read" {
  count = var.s3_bucket_arn != "" ? 1 : 0

  name   = "${var.name}-ec2-s3-read"
  role   = aws_iam_role.ec2.id
  policy = data.aws_iam_policy_document.ec2_s3_read[0].json
}

data "aws_iam_policy_document" "ec2_cw" {
  count = length(var.cw_log_group_arns) > 0 ? 1 : 0

  statement {
    sid    = "CloudWatchAgent"
    effect = "Allow"

    actions = [
      "cloudwatch:PutMetricData",
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:ListMetrics",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
    ]

    resources = concat(
      var.cw_log_group_arns,
      ["arn:${data.aws_partition.current.partition}:logs:${data.aws_caller_identity.current.account_id}:*:*"],
    )
  }
}

resource "aws_iam_role_policy" "ec2_cw" {
  count = length(var.cw_log_group_arns) > 0 ? 1 : 0

  name   = "${var.name}-ec2-cloudwatch"
  role   = aws_iam_role.ec2.id
  policy = data.aws_iam_policy_document.ec2_cw[0].json
}

resource "aws_iam_role_policy_attachment" "ec2_ssm_core" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.name}-ec2-profile"
  role = aws_iam_role.ec2.name

  tags = var.tags
}

# -- GitHub Actions OIDC role -------------------------------------------------

data "aws_iam_policy_document" "gha_assume" {
  statement {
    sid     = "GitHubActionsAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.github_oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = concat(
        [for branch in var.github_branches : "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/${branch}"],
        [for branch in var.github_branches : "repo:${var.github_org}/${var.github_repo}:environment:${branch}"],
      )
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "${var.name}-gha-role"
  assume_role_policy = data.aws_iam_policy_document.gha_assume.json
  max_session_duration = 3600

  tags = var.tags
}

data "aws_iam_policy_document" "gha_terraform" {
  statement {
    sid    = "TerraformState"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
    ]

    resources = [
      "arn:${data.aws_partition.current.partition}:s3:::${var.name}-tfstate-*",
      "arn:${data.aws_partition.current.partition}:s3:::${var.name}-tfstate-*/*",
    ]
  }

  statement {
    sid    = "TerraformLock"
    effect = "Allow"

    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
      "dynamodb:DescribeTable",
    ]

    resources = [
      "arn:${data.aws_partition.current.partition}:dynamodb:${data.aws_caller_identity.current.account_id}:*/tf-state-lock",
    ]
  }

  statement {
    sid    = "TerraformEC2"
    effect = "Allow"

    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeImages",
      "ec2:DescribeVpcs",
      "ec2:DescribeSubnets",
      "ec2:DescribeRouteTables",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeAddresses",
      "ec2:DescribeNatGateways",
      "ec2:DescribeInternetGateways",
      "ec2:AssociateAddress",
      "ec2:DisassociateAddress",
      "ec2:AllocateAddress",
      "ec2:ReleaseAddress",
      "ec2:CreateSecurityGroup",
      "ec2:DeleteSecurityGroup",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:CreateTags",
      "ec2:DeleteTags",
    ]

    resources = ["*"]
  }

  statement {
    sid    = "TerraformIAM"
    effect = "Allow"

    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:GetRole",
      "iam:PassRole",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:CreateInstanceProfile",
      "iam:DeleteInstanceProfile",
      "iam:GetInstanceProfile",
      "iam:AddRoleToInstanceProfile",
      "iam:RemoveRoleFromInstanceProfile",
      "iam:CreatePolicy",
      "iam:DeletePolicy",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:ListPolicyVersions",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicyVersion",
      "iam:SetDefaultPolicyVersion",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:GetRolePolicy",
      "iam:ListAttachedRolePolicies",
      "iam:ListRolePolicies",
    ]

    resources = [
      "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/${var.name}*",
      "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:policy/${var.name}*",
      "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:instance-profile/${var.name}*",
    ]
  }

  statement {
    sid    = "TerraformS3"
    effect = "Allow"

    actions = [
      "s3:CreateBucket",
      "s3:DeleteBucket",
      "s3:GetBucket*",
      "s3:ListBucket",
      "s3:ListAllMyBuckets",
      "s3:PutBucket*",
      "s3:GetBucketPolicy",
      "s3:PutBucketPolicy",
      "s3:DeleteBucketPolicy",
      "s3:GetEncryptionConfiguration",
      "s3:PutEncryptionConfiguration",
      "s3:GetLifecycleConfiguration",
      "s3:PutLifecycleConfiguration",
      "s3:GetPublicAccessBlock",
      "s3:PutPublicAccessBlock",
      "s3:GetBucketVersioning",
      "s3:PutBucketVersioning",
      "s3:GetBucketAcl",
      "s3:PutBucketAcl",
    ]

    resources = [
      "arn:${data.aws_partition.current.partition}:s3:::${var.name}-*",
      "arn:${data.aws_partition.current.partition}:s3:::*",
    ]
  }

  statement {
    sid    = "TerraformCloudWatch"
    effect = "Allow"

    actions = [
      "cloudwatch:DescribeAlarms",
      "cloudwatch:PutMetricAlarm",
      "cloudwatch:DeleteAlarms",
      "cloudwatch:TagResource",
      "cloudwatch:UntagResource",
      "cloudwatch:ListTagsForResource",
      "logs:CreateLogGroup",
      "logs:DeleteLogGroup",
      "logs:DescribeLogGroups",
      "logs:TagResource",
      "logs:UntagResource",
      "logs:ListTagsForResource",
    ]

    resources = ["*"]
  }

  statement {
    sid    = "TerraformSNS"
    effect = "Allow"

    actions = [
      "sns:CreateTopic",
      "sns:DeleteTopic",
      "sns:Subscribe",
      "sns:Unsubscribe",
      "sns:ListSubscriptions",
      "sns:ListSubscriptionsByTopic",
      "sns:GetTopicAttributes",
      "sns:SetTopicAttributes",
      "sns:TagResource",
      "sns:UntagResource",
    ]

    resources = [
      "arn:${data.aws_partition.current.partition}:sns:${data.aws_caller_identity.current.account_id}:${var.name}-*",
    ]
  }

  statement {
    sid    = "TerraformVPC"
    effect = "Allow"

    actions = [
      "ec2:CreateVpc",
      "ec2:DeleteVpc",
      "ec2:ModifyVpcAttribute",
      "ec2:DescribeVpcAttribute",
      "ec2:CreateSubnet",
      "ec2:DeleteSubnet",
      "ec2:CreateInternetGateway",
      "ec2:DeleteInternetGateway",
      "ec2:AttachInternetGateway",
      "ec2:DetachInternetGateway",
      "ec2:CreateRouteTable",
      "ec2:DeleteRouteTable",
      "ec2:AssociateRouteTable",
      "ec2:DisassociateRouteTable",
      "ec2:CreateRoute",
      "ec2:DeleteRoute",
      "ec2:ReplaceRoute",
      "ec2:CreateNatGateway",
      "ec2:DeleteNatGateway",
    ]

    resources = ["*"]
  }

  statement {
    sid    = "TerraformOIDC"
    effect = "Allow"

    actions = [
      "iam:CreateOpenIDConnectProvider",
      "iam:DeleteOpenIDConnectProvider",
      "iam:GetOpenIDConnectProvider",
      "iam:TagOpenIDConnectProvider",
      "iam:UntagOpenIDConnectProvider",
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "github_actions_terraform" {
  name   = "${var.name}-gha-terraform"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.gha_terraform.json
}