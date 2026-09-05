output "sns_topic_arn" {
  description = "ARN of the SNS topic that receives CloudWatch alarm notifications."
  value       = aws_sns_topic.alerts.arn
}

output "sns_topic_name" {
  description = "Name of the SNS topic."
  value       = aws_sns_topic.alerts.name
}

output "log_group_name" {
  description = "Name of the application CloudWatch Log Group."
  value       = aws_cloudwatch_log_group.app.name
}

output "log_group_arn" {
  description = "ARN of the application CloudWatch Log Group."
  value       = aws_cloudwatch_log_group.app.arn
}

output "ec2_cpu_alarm_arn" {
  description = "ARN of the EC2 CPU high-utilization alarm."
  value       = aws_cloudwatch_metric_alarm.ec2_cpu_high.arn
}

output "ec2_status_check_alarm_arn" {
  description = "ARN of the EC2 status check alarm."
  value       = aws_cloudwatch_metric_alarm.ec2_status_check.arn
}

output "billing_alarm_arn" {
  description = "ARN of the estimated-charges billing alarm."
  value       = aws_cloudwatch_metric_alarm.billing.arn
}