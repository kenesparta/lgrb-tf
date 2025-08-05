# locals {
#   private_s3_bucket = "s3private.${var.main_dns}"
# }
#
# resource "aws_s3_bucket" "private_bucket" {
#   bucket = local.private_s3_bucket
#   force_destroy = true
# }
#
# resource "aws_s3_bucket_policy" "private_policy" {
#   bucket = aws_s3_bucket.private_bucket.id
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Principal = {
#           Service = "cloudfront.amazonaws.com"
#         }
#         Action = "s3:GetObject"
#         Resource = "${aws_s3_bucket.private_bucket.arn}/*"
#         Condition = {
#           StringEquals = {
#             "AWS:SourceArn" = aws_cloudfront_distribution.cdn.arn
#           }
#         }
#       }
#     ]
#   })
# }
#
# resource "aws_cloudfront_origin_access_control" "oac" {
#   name   = "example-oac"
#   origin_access_control_origin_type = "S3"
#   signing_behavior                  = "always"
#   signing_protocol                  = "sigv4"
# }
#
# resource "aws_cloudfront_distribution" "cdn" {
#   enabled       = true
#   default_root_object = "index.html"
#
#   origin {
#     domain_name = aws_s3_bucket.private_bucket.bucket_regional_domain_name
#     origin_id   = "S3-private-bucket"
#     s3_origin_config {
#       origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
#       origin_access_identity   = ""
#     }
#   }
#
#   default_cache_behavior {
#     target_origin_id       = "S3-private-bucket"
#     viewer_protocol_policy = "redirect-to-https"
#
#     allowed_methods = ["GET", "HEAD"]
#     cached_methods  = ["GET", "HEAD"]
#
#     forwarded_values {
#       query_string = false
#       cookies {
#         forward = "none"
#       }
#     }
#   }
#
#   restrictions {
#     geo_restriction {
#       restriction_type = "none"
#     }
#   }
#
#   viewer_certificate {
#     cloudfront_default_certificate = true
#   }
# }