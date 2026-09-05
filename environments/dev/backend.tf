terraform {
  backend "s3" {
    # Bucket and key are configured per-environment via `-backend-config` flags
    # or the CLI. Do not hardcode here so the same root can target dev / prod.
    # Example local override:
    #   terraform init \
    #     -backend-config="bucket=myproject-tfstate-us-east-1" \
    #     -backend-config="key=dev/terraform.tfstate" \
    #     -backend-config="region=us-east-1" \
    #     -backend-config="dynamodb_table=myproject-tf-state-lock"
  }
}