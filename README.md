# AWS Infrastructure as Code (Terraform)

Production-style Terraform project that provisions and manages a complete AWS
environment — VPC, EC2, S3, IAM, CloudWatch monitoring, and CI/CD — with
remote state, OIDC-based GitHub Actions auth, and least-privilege IAM.

| Component | Implementation |
| --- | --- |
| **Networking** | Custom VPC, 2 public + 2 private subnets across 2 AZs, IGW, NAT Gateway, route tables |
| **Compute** | EC2 (`t3.micro`, Amazon Linux 2023) in a public subnet, IMDSv2 required |
| **Storage** | S3 app bucket (versioning, SSE-S3, public access block, lifecycle rule) |
| **IAM** | EC2 instance role (least-privilege S3 + CW + SSM), GitHub Actions OIDC role |
| **Monitoring** | SNS topic + email, CW alarms (CPU, status check, billing), CW Log Group |
| **CI/CD** | GitHub Actions: `fmt`/`validate`/`plan` on PR, `apply` on merge to `main` (OIDC, no static keys) |
| **State** | S3 + DynamoDB lock (created via `bootstrap/`) |

---

## Architecture

```
                       ┌──────────────────────────────────────┐
                       │                  VPC                 │
                       │                10.0.0.0/16          │
                       │                                      │
  SSH/HTTP/HTTPS  ───► │  ┌────────────┐    ┌────────────┐    │
  (Internet)           │  │ Public AZa │    │ Public AZb │    │
                       │  │ 10.0.1.0/24│    │ 10.0.2.0/24│    │
                       │  │ ┌────────┐ │    │            │    │
                       │  │ │  EC2  │ │    │            │    │
                       │  │ │ AL2023│ │    │            │    │
                       │  │ └───┬────┘ │    │            │    │
                       │  │     │      │    │            │    │
                       │  │ ┌───▼────┐ │    │   ┌────────┐│    │
                       │  │ │NAT GW ├─┼────┼───┤ EIP    ││    │
                       │  │ └───┬────┘ │    │   └────────┘│    │
                       │  └─────┼──────┘    └─────────────┘   │
                       │        │             ▲               │
                       │        ▼ 0.0.0.0/0   │ IGW           │
                       │  ┌─────────────┐ ┌───────────────┐    │
                       │  │ Private AZa │ │ Private AZb   │    │
                       │  │10.0.10.0/24 │ │10.0.11.0/24   │    │
                       │  └─────────────┘ └───────────────┘    │
                       └──────────────────────────────────────┘

  EC2 ──► S3 (app bucket, versioned + encrypted, no public access)
  EC2 ──► CloudWatch (metrics + logs via instance role, IMDSv2 required)
  CloudWatch Alarms ──► SNS topic ──► email subscription
  Billing alarm (us-east-1) ──► same SNS topic

  GitHub Actions ──(OIDC)──► IAM Role (assumes) ──► Terraform plan & apply
```

---

## Prerequisites

- **AWS account** with permission to create VPC, EC2, S3, DynamoDB, IAM, SNS, CloudWatch resources.
- **Terraform >= 1.5** (or OpenTofu >= 1.6). This repo is tested against Terraform 1.10.x.
- **AWS CLI v2** for the bootstrap step and verification.
- **GitHub repository** with Actions enabled. The workflow uses **OIDC** — you do **not** store AWS access keys in GitHub Secrets.

### Tool versions verified at authoring time

| Tool | Version |
| --- | --- |
| Terraform | `>= 1.5.0` (CI pinned to `1.10.5`) |
| AWS provider | `~> 6.0` (currently 6.x) |
| `hashicorp/setup-terraform` | `v4` |
| `aws-actions/configure-aws-credentials` | `v4` |

> Note: the original brief specified AWS provider `~> 5.0`, but the
> `hashicorp/aws` provider is on the 6.x major release line as of this writing.
> The modules pin to `~> 6.0` and are written against the current 6.x docs.

---

## One-time bootstrap: remote state backend

The S3 bucket and DynamoDB table that store/lock Terraform state **must exist
before** any `environments/*` can `terraform init` against the backend. They
are therefore created by a separate, lightweight root (`bootstrap/`) that uses
the **local** backend.

```bash
cd bootstrap

terraform init

terraform apply \
  -var="project_name=aws-iac-portfolio" \
  -var="aws_region=us-east-1" \
  -var="owner=you@example.com"
```

Take note of the outputs — you will use them as `-backend-config` values when
initializing an environment:

```
state_bucket_name     = "aws-iac-portfolio-tfstate-us-east-1"
state_lock_table_name = "aws-iac-portfolio-tf-state-lock"
```

Re-run this `bootstrap/` apply any time you want to recreate the state
infrastructure (e.g. in a new account). To **tear down** the state bucket,
first run `terraform destroy` in the environment(s) that use it, then
re-apply bootstrap with `force_destroy = true` and destroy again.

---

## GitHub Actions OIDC setup (one-time, per AWS account)

The CI/CD pipeline authenticates to AWS via OIDC federation — no static IAM
user keys. This repo's IAM module provisions both the OIDC provider and the
deploy role on first apply, but you still need to register the trust in IAM
*before* the workflow can assume the role.

**Option A — let this Terraform stack create everything (recommended).**
On the first `terraform apply`, the `iam` module creates:

- `aws_iam_openid_connect_provider` for `token.actions.githubusercontent.com`
- `aws_iam_role.github_actions` with a trust policy restricted to
  `repo:<org>/<repo>:ref:refs/heads/main` and audience `sts.amazonaws.com`

After it applies, copy the role ARN from the output (`github_actions_role_arn`)
into the GitHub Actions secret `AWS_DEPLOY_ROLE_ARN` (Settings → Secrets and
variables → Actions).

**Option B — pre-create the OIDC provider manually** (e.g. via the AWS console
or a separate Terraform stack). In that case set
`create_github_oidc_provider = false` and provide the existing
`oidc_provider_arn` in your tfvars.

### Required GitHub Actions secrets / variables

| Secret / Variable | Value |
| --- | --- |
| `AWS_DEPLOY_ROLE_ARN` (secret) | ARN of the IAM role created by the `iam` module |
| `AWS_ACCOUNT_ID` (variable, optional) | Hardening: restricts `aws-actions/configure-aws-credentials` to this account only |

No `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` secrets are needed.

---

## Local setup & deployment

```bash
# 1. Configure local AWS credentials (any principal with admin or the
#    permissions listed in the IAM module can do this).
aws configure sso    # or `aws configure` for long-lived keys you keep locally

# 2. Configure the dev environment.
cd environments/dev
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars
#   - set alert_email, github_org, github_repo
#   - narrow ec2_ssh_cidr_blocks away from 0.0.0.0/0
#   - set app_bucket_name to a globally-unique name

# 3. Initialize the backend (uses the bucket/table from the bootstrap step).
terraform init \
  -backend-config="bucket=aws-iac-portfolio-tfstate-us-east-1" \
  -backend-config="key=dev/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=aws-iac-portfolio-tf-state-lock"

# 4. Plan & apply.
terraform plan
terraform apply
```

### Optional: pass backend config via a backend config file

Create `environments/dev/dev.backend.tfvars`:

```
bucket         = "aws-iac-portfolio-tfstate-us-east-1"
key            = "dev/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "aws-iac-portfolio-tf-state-lock"
encrypt        = true
```

Then `terraform init -backend-config=dev.backend.tfvars`.

---

## GitHub Actions deployment

1. Push to a feature branch → open a PR against `main`.
   - The workflow runs `terraform fmt -check`, `terraform validate`, and
     `terraform plan`, and **posts the plan as a comment on the PR**.
2. Merge to `main` → the workflow re-runs and **auto-applies** to the dev
   environment.

Both jobs assume the `AWS_DEPLOY_ROLE_ARN` role via OIDC; no AWS keys are
stored in GitHub.

---

## Variable reference

All variables live in `environments/dev/variables.tf`. Defaults are sensible
but you must override the security-sensitive ones.

| Variable | Default | Description |
| --- | --- | --- |
| `aws_region` | `us-east-1` | AWS region for the dev environment. |
| `environment` | `dev` | Environment name (used in tags). |
| `project_name` | `aws-iac-portfolio` | Resource name prefix. |
| `owner` | `platform-team@example.com` | `Owner` tag. |
| `vpc_cidr` | `10.0.0.0/16` | VPC CIDR. |
| `availability_zones` | `["us-east-1a","us-east-1b"]` | Two AZs for HA. |
| `public_subnet_cidrs` | `["10.0.1.0/24","10.0.2.0/24"]` | One per AZ. |
| `private_subnet_cidrs` | `["10.0.10.0/24","10.0.11.0/24"]` | One per AZ. |
| `ec2_instance_type` | `t3.micro` | EC2 instance type. |
| `ec2_key_pair_name` | `null` | Name of an **existing** EC2 Key Pair (private key is NOT managed here). |
| `ec2_ssh_cidr_blocks` | `["0.0.0.0/0"]` | **MUST narrow in tfvars.** |
| `ec2_ingress_cidr_blocks` | `["0.0.0.0/0"]` | HTTP/HTTPS source CIDRs. |
| `ec2_root_volume_size_gb` | `20` | Root EBS volume GiB. |
| `app_bucket_name` | `null` | Globally-unique S3 bucket name. |
| `app_bucket_force_destroy` | `false` | Set `true` for dev only. |
| `app_bucket_glacier_transition_days` | `90` | Transition to Glacier after N days. |
| `app_bucket_noncurrent_expiration_days` | `365` | Expire noncurrent versions. |
| `alert_email` | **(required)** | Receives SNS alarm emails (confirm from inbox). |
| `billing_alarm_threshold_usd` | `25` | Estimated charges that trip the billing alarm. |
| `log_group_retention_days` | `30` | CW Log Group retention. |
| `github_org` | **(required)** | GitHub org/user owning the repo. |
| `github_repo` | **(required)** | GitHub repo allowed to assume the deploy role. |
| `github_branches` | `["main"]` | Git refs allowed to assume the deploy role. |
| `create_github_oidc_provider` | `true` | Create the OIDC provider if it doesn't exist. |
| `oidc_provider_arn` | `""` | Use an existing OIDC provider when `create_github_oidc_provider=false`. |

---

## Cost-awareness notes

Resources that **can incur cost** (default settings, us-east-1):

| Resource | Cost driver |
| --- | --- |
| **NAT Gateway** | ~$0.045/hr + per-GB data processing. Single NAT, single AZ (HA-NAT is a separate enhancement). |
| **EC2 (`t3.micro`)** | Free Tier eligible for 12 months; otherwise ~$0.0104/hr. |
| **EBS (gp3, 20 GiB)** | ~$0.08/GB-month. |
| **EIP attached to NAT** | Free while attached to a running NAT. |
| **S3 app bucket** | Negligible at dev volumes; storage + GET/PUT request charges apply. |
| **DynamoDB lock table** | PAY_PER_REQUEST — typically <$0.01/mo. |
| **SNS** | Free for email subscriptions; $0.50/100k notifications. |
| **CloudWatch** | Metric ingest, alarm hours, log ingestion/storage. |
| **State S3 bucket** | Negligible; storage + versioning. |

**Estimated dev-environment floor (excluding data transfer):** ~$35–45/month
mostly from NAT + EBS.

---

## Security notes

- **No long-lived AWS access keys in CI.** GitHub Actions authenticates via
  OIDC federation with a trust policy that pins
  `repo:<org>/<repo>:ref:refs/heads/main` and audience `sts.amazonaws.com`.
- **Least-privilege IAM.** No `*:*` anywhere. EC2 role only gets
  `s3:GetObject`/`ListBucket` on the app bucket, plus the minimum CloudWatch
  Agent + SSM Session Manager permissions.
- **SSH is variable-driven.** Defaults to `0.0.0.0/0` for ergonomics but
  `terraform plan` will still pass — **narrow it in `terraform.tfvars`** to
  your own IP (or a VPN CIDR).
- **IMDSv2 required** on the EC2 instance (`http_tokens = "required"` +
  `hop_limit = 1`).
- **EBS root volume encrypted** (`gp3`, encrypted by default in the module).
- **S3 public access blocked** on every bucket. Versioning and SSE-S3 enabled.
- **SNS topic policy** scoped to `cloudwatch.amazonaws.com` from the same AWS
  account.
- **No hardcoded account IDs or ARNs** anywhere; the IAM module uses data
  sources (`aws_caller_identity`, `aws_partition`) and constructs ARNs from
  them.

---

## Outputs

The dev root surfaces these outputs (see `environments/dev/outputs.tf`):

- `vpc_id`, `vpc_cidr_block`, `public_subnet_ids`, `private_subnet_ids`
- `ec2_instance_id`, `ec2_public_ip`, `ec2_private_ip`, `ec2_security_group_id`, `ec2_ami_id`
- `app_bucket_name`, `app_bucket_arn`, `app_bucket_domain_name`
- `ec2_iam_role_arn`, `ec2_instance_profile_name`
- `github_actions_role_arn`, `github_oidc_provider_arn`
- `sns_topic_arn`, `cloudwatch_log_group_name`

---

## Cleanup / teardown

```bash
# Destroy the dev environment
cd environments/dev
terraform destroy

# Destroy the bootstrap (state + lock). ONLY after all environments are gone.
cd ../../bootstrap
terraform apply -var="force_destroy=true"   # so the bucket is droppable
terraform destroy
```

To save money immediately when you're done iterating, also release the NAT
Gateway's EIP and terminate the EC2 instance (both happen automatically as
part of `terraform destroy`).

---

## Project layout

```
.
├── .github/workflows/terraform.yml    # fmt / validate / plan / apply via OIDC
├── bootstrap/                         # one-time state-bucket + lock-table
│   ├── main.tf  variables.tf  outputs.tf  versions.tf
├── modules/
│   ├── vpc/        # VPC, IGW, NAT, subnets, route tables
│   ├── ec2/        # EC2 + security group, Amazon Linux 2023
│   ├── s3/         # Versioned, encrypted, public-access-blocked bucket
│   ├── iam/        # EC2 role + GitHub Actions OIDC role
│   └── monitoring/ # SNS topic, email sub, CW alarms (CPU, status, billing), CW log group
├── environments/dev/
│   ├── main.tf  outputs.tf  variables.tf  versions.tf  backend.tf
│   └── terraform.tfvars.example
├── .gitignore
└── README.md
```