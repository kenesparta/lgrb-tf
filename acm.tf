data "aws_acm_certificate" "lgr_web_certificate" {
  domain   = "*.rustybootcamp.xyz"
  statuses = ["ISSUED"]
}
