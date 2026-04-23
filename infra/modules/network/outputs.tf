output "vpc_id" {
  description = "VPC ID."
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs."
  value       = [for subnet in aws_subnet.public : subnet.id]
}

output "availability_zones" {
  description = "Availability zones used by the public subnets."
  value       = [for subnet in aws_subnet.public : subnet.availability_zone]
}
