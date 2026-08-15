# 1. S3 Bucket for Static Frontend Build (Non-public) (Checklist #22)
resource "aws_s3_bucket" "frontend" {
  bucket        = "${lower(var.project_name)}-frontend-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = {
    Name = "${var.project_name}-frontend-bucket"
  }
}

# Block public access for CloudFront; Allow public bucket policy for direct S3 Static Website Hosting
resource "aws_s3_bucket_public_access_block" "frontend_block" {
  bucket                  = aws_s3_bucket.frontend.id
  block_public_acls       = var.enable_cloudfront ? true : false
  block_public_policy     = var.enable_cloudfront ? true : false
  ignore_public_acls      = var.enable_cloudfront ? true : false
  restrict_public_buckets = var.enable_cloudfront ? true : false
}

# 1b. S3 Static Website Hosting Configuration (Fallback when CloudFront is disabled)
resource "aws_s3_bucket_website_configuration" "frontend_website" {
  count  = var.enable_cloudfront ? 0 : 1
  bucket = aws_s3_bucket.frontend.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

# 2. CloudFront Origin Access Control (OAC) (Checklist #22)
resource "aws_cloudfront_origin_access_control" "oac" {
  count                             = var.enable_cloudfront ? 1 : 0
  name                              = "${var.project_name}-oac"
  description                       = "Origin Access Control for TicketDesk Frontend S3 Bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# 3a. S3 Bucket Policy allowing CloudFront OAC read (When CloudFront is enabled)
resource "aws_s3_bucket_policy" "frontend_policy" {
  count  = var.enable_cloudfront ? 1 : 0
  bucket = aws_s3_bucket.frontend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontServicePrincipalReadOnly"
        Effect    = "Allow"
        Principal = { Service = "cloudfront.amazonaws.com" }
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.frontend.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.cdn[0].arn
          }
        }
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.frontend_block]
}

# 3b. S3 Bucket Policy allowing Public Read for Direct S3 Website Hosting (When CloudFront is disabled)
resource "aws_s3_bucket_policy" "frontend_public_policy" {
  count  = var.enable_cloudfront ? 0 : 1
  bucket = aws_s3_bucket.frontend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.frontend.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.frontend_block]
}

# 4. CloudFront Distribution (Checklist #22)
resource "aws_cloudfront_distribution" "cdn" {
  count           = var.enable_cloudfront ? 1 : 0
  enabled         = true
  is_ipv6_enabled = true
  comment         = "TicketDesk Frontend CDN"

  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = "S3-${aws_s3_bucket.frontend.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac[0].id
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.frontend.id}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name = "${var.project_name}-cdn"
  }
}
