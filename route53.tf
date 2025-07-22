data "aws_route53_zone" "main" {
  name = var.main_dns
}

resource "aws_route53_record" "app_service" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "app.${var.main_dns}"
  type    = "A"

  alias {
    name                   = aws_lb.app_service_alb.dns_name
    zone_id                = aws_lb.app_service_alb.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "auth_service" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "auth.${var.main_dns}"
  type    = "A"

  alias {
    name                   = aws_lb.auth_service_alb.dns_name
    zone_id                = aws_lb.auth_service_alb.zone_id
    evaluate_target_health = true
  }
}
