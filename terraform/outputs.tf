output "cloudfront_domain_name" {
  description = "CloudFront Distribution Domain Name (Static App & API Gateway)"
  value       = var.enable_cloudfront ? aws_cloudfront_distribution.cdn[0].domain_name : aws_lb.main.dns_name
}


output "alb_dns_name" {
  description = "Application Load Balancer DNS Name"
  value       = aws_lb.main.dns_name
}

output "rds_endpoint" {
  description = "RDS MySQL Database Endpoint"
  value       = aws_db_instance.main.endpoint
}

output "ecr_repository_url" {
  description = "ECR Repository URL for API container image"
  value       = aws_ecr_repository.api.repository_url
}

output "s3_frontend_bucket" {
  description = "S3 Bucket for Frontend static hosting"
  value       = aws_s3_bucket.frontend.id
}

output "s3_attachments_bucket" {
  description = "S3 Bucket for Attachments"
  value       = aws_s3_bucket.attachments.id
}

output "cloudwatch_dashboard_name" {
  description = "Name of CloudWatch Dashboard"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}
