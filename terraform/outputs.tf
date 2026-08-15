output "alb_dns_name" {
  description = "Application Load Balancer DNS Name (Primary Application Entry Point)"
  value       = aws_lb.main.dns_name
}

output "application_url" {
  description = "Primary TicketDesk Application Endpoint URL"
  value       = "http://${aws_lb.main.dns_name}"
}

output "ecr_repository_url" {
  description = "Amazon ECR Repository URL for TicketDesk API container images"
  value       = aws_ecr_repository.api.repository_url
}

output "rds_endpoint" {
  description = "RDS MySQL Database Instance Endpoint"
  value       = aws_db_instance.main.endpoint
}

output "s3_attachments_bucket" {
  description = "S3 Attachments Bucket Name"
  value       = aws_s3_bucket.attachments.id
}

output "s3_frontend_bucket" {
  description = "S3 Frontend Build Bucket Name"
  value       = aws_s3_bucket.frontend.id
}

output "s3_website_endpoint" {
  description = "Direct S3 Static Website Hosting Endpoint URL"
  value       = aws_s3_bucket_website_configuration.frontend_website[0].website_endpoint
}
