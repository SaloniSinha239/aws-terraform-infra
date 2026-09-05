variable "name" {
  description = "Name prefix for monitoring resources."
  type        = string
}

variable "alert_email" {
  description = "Email address that will receive alarm notifications. Confirmation required from the inbox on first use."
  type        = string
}

variable "ec2_instance_id" {
  description = "EC2 instance ID to monitor (for CPU and status check alarms)."
  type        = string
}

variable "billing_alarm_threshold_usd" {
  description = "Estimated monthly charges (USD) that trigger the billing alarm. The AWS/Billing metric is published only in us-east-1, which is where this alarm is created regardless of the provider region."
  type        = number
  default     = 25
}

variable "log_group_retention_days" {
  description = "Retention period for the application CloudWatch Log Group."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags applied to all monitoring resources."
  type        = map(string)
  default     = {}
}