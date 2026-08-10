variable "aws_region" {
  type        = string
  description = "AWS region for deployment"
  default     = "us-east-1"
}

variable "project_name" {
  type        = string
  description = "Project name tag"
  default     = "TicketDesk"
}

variable "owner" {
  type        = string
  description = "Owner tag"
  default     = "Pod-Team"
}

variable "environment" {
  type        = string
  description = "Environment tag"
  default     = "Production"
}

variable "cost_center" {
  type        = string
  description = "Cost Center tag"
  default     = "POC-2026"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for public subnets"
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for private subnets"
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "db_name" {
  type        = string
  description = "MySQL Database name"
  default     = "ticketdesk_db"
}

variable "db_username" {
  type        = string
  description = "MySQL Master username"
  default     = "ticketdesk_admin"
}

variable "app_port" {
  type        = number
  description = "Port exposed by the ECS application container"
  default     = 8080
}

variable "alarm_email" {
  type        = string
  description = "Email address for SNS CloudWatch alarm notifications"
  default     = "admin@example.com"
}

variable "enable_cloudfront" {
  type        = bool
  description = "Enable CloudFront CDN distribution (requires verified AWS account)"
  default     = false
}

