locals {
  private_s3_bucket = "s3private.${var.main_dns}"
}

resource "aws_s3_bucket" "private_app_bucket" {
  bucket        = local.private_s3_bucket
  force_destroy = true
  tags = {
    Name        = local.private_s3_bucket
    Environment = "Production"
    Description = "Private S3 bucket for restricted content"
  }
}

resource "aws_s3_bucket_public_access_block" "private_app_bucket_pab" {
  bucket = aws_s3_bucket.private_app_bucket.id

  block_public_acls       = true
  block_public_policy     = false
  ignore_public_acls      = true
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "private_app_bucket_policy" {
  bucket = aws_s3_bucket.private_app_bucket.id

  depends_on = [aws_s3_bucket_public_access_block.private_app_bucket_pab]

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "EnforcePresignedURLAccess",
        Effect    = "Allow",
        Principal = "*",
        Action    = "s3:GetObject",
        Resource  = "${aws_s3_bucket.private_app_bucket.arn}/*",
        Condition = {
          Bool = {
            "aws:SecureTransport" = "true"
          },
          StringEquals = {
            "s3:signatureversion" = "AWS4-HMAC-SHA256"
          }
        }
      }
    ]
  })
}
