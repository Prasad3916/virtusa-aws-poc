# 1. Random password generator for DB
resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# 2. Secrets Manager Secret for DB Credentials
resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${var.project_name}-db-credentials"
  recovery_window_in_days = 0

  tags = {
    Name = "${var.project_name}-db-credentials"
  }
}

# 3. Secret Version holding JSON object
resource "aws_secretsmanager_secret_version" "db_credentials_val" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_password.result
    engine   = "mysql"
    port     = 3306
  })
}

# 4. SSM Parameter Store - Database Host
resource "aws_ssm_parameter" "db_host" {
  name        = "/${lower(var.project_name)}/DB_HOST"
  description = "Database Host endpoint"
  type        = "String"
  value       = aws_db_instance.main.address
  overwrite   = true
}

# 5. SSM Parameter Store - Database Name
resource "aws_ssm_parameter" "db_name" {
  name        = "/${lower(var.project_name)}/DB_NAME"
  description = "Database Name"
  type        = "String"
  value       = var.db_name
  overwrite   = true
}

# 6. SSM Parameter Store - S3 Attachments Bucket
resource "aws_ssm_parameter" "s3_bucket" {
  name        = "/${lower(var.project_name)}/S3_BUCKET"
  description = "S3 Attachments Bucket Name"
  type        = "String"
  value       = aws_s3_bucket.attachments.id
  overwrite   = true
}
