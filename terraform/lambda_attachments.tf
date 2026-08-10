# 1. S3 Bucket for Attachments (Public Access Blocked, CORS enabled)
resource "aws_s3_bucket" "attachments" {
  bucket        = "${lower(var.project_name)}-attachments-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = {
    Name = "${var.project_name}-attachments-bucket"
  }
}


# Encryption at rest (Checklist #20)
resource "aws_s3_bucket_server_side_encryption_configuration" "attachments_enc" {
  bucket = aws_s3_bucket.attachments.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block Public Access (Checklist #22)
resource "aws_s3_bucket_public_access_block" "attachments_block" {
  bucket                  = aws_s3_bucket.attachments.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CORS rule for direct S3 presigned URL uploads from browser
resource "aws_s3_bucket_cors_configuration" "attachments_cors" {
  bucket = aws_s3_bucket.attachments.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "POST", "GET", "HEAD"]
    allowed_origins = ["*"]
    max_age_seconds = 3000
  }
}

# 2. Package Lambda code into zip archive
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda"
  output_path = "${path.module}/../lambda/thumbnail_generator.zip"
}

# 3. IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Scoped Policy for Lambda Role (S3 Get/Put and CloudWatch Logs)
resource "aws_iam_policy" "lambda_policy" {
  name        = "${var.project_name}-lambda-policy"
  description = "Scoped permissions for thumbnail generator Lambda"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.attachments.arn}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# 4. Lambda Function
resource "aws_lambda_function" "thumbnail_generator" {
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  function_name    = "${var.project_name}-thumbnail-generator"
  role             = aws_iam_role.lambda_role.arn
  handler          = "thumbnail_generator.handler"
  runtime          = "python3.11"
  timeout          = 30

  environment {
    variables = {
      DESTINATION_PREFIX = "thumbnails/"
    }
  }

  tags = {
    Name = "${var.project_name}-thumbnail-generator"
  }
}

# 5. Permission for S3 to invoke Lambda
resource "aws_lambda_permission" "allow_s3_invoke" {
  statement_id  = "AllowS3InvokeThumbnailGenerator-${data.aws_caller_identity.current.account_id}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.thumbnail_generator.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.attachments.arn
}



# 6. S3 Event Notification triggering Lambda on object creation under uploads/
resource "aws_s3_bucket_notification" "s3_trigger" {
  bucket = aws_s3_bucket.attachments.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.thumbnail_generator.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "uploads/"
  }

  depends_on = [aws_lambda_permission.allow_s3_invoke]
}
