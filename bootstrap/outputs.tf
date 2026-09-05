output "state_bucket_name" {
  description = "Name of the S3 bucket holding Terraform state."
  value       = aws_s3_bucket.tfstate.id
}

output "state_bucket_arn" {
  description = "ARN of the S3 bucket holding Terraform state."
  value       = aws_s3_bucket.tfstate.arn
}

output "state_lock_table_name" {
  description = "Name of the DynamoDB table used for state locking."
  value       = aws_dynamodb_table.tf_lock.name
}

output "state_lock_table_arn" {
  description = "ARN of the DynamoDB table used for state locking."
  value       = aws_dynamodb_table.tf_lock.arn
}