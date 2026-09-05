output "instance_id" {
  description = "EC2 instance ID."
  value       = aws_instance.this.id
}

output "instance_arn" {
  description = "EC2 instance ARN."
  value       = aws_instance.this.arn
}

output "instance_public_ip" {
  description = "Public IP address of the instance (only present when launched in a public subnet with an associated public IP)."
  value       = aws_instance.this.public_ip
}

output "instance_private_ip" {
  description = "Private IP address of the instance."
  value       = aws_instance.this.private_ip
}

output "instance_state" {
  description = "Current state of the instance."
  value       = aws_instance.this.instance_state
}

output "security_group_id" {
  description = "ID of the EC2 security group."
  value       = aws_security_group.this.id
}

output "ami_id" {
  description = "ID of the Amazon Linux 2023 AMI used."
  value       = data.aws_ami.amazon_linux_2023.id
}