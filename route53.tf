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

resource "aws_route53_record" "grpc_service" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "grpc.${var.main_dns}"
  type    = "A"

  alias {
    name                   = aws_lb.auth_service_alb.dns_name
    zone_id                = aws_lb.auth_service_alb.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "ses_domain_verification" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "_amazonses.${aws_ses_domain_identity.rustybootcamp.domain}"
  type    = "TXT"
  ttl     = 300
  records = [aws_ses_domain_identity.rustybootcamp.verification_token]
}

resource "aws_route53_record" "ses_dkim_records" {
  count   = 1
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "${aws_ses_domain_dkim.rustybootcamp.dkim_tokens[count.index]}._domainkey"
  type    = "CNAME"
  ttl     = 300
  records = ["${aws_ses_domain_dkim.rustybootcamp.dkim_tokens[count.index]}.dkim.amazonses.com"]
}

resource "aws_route53_record" "dmarc" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "_dmarc.${var.main_dns}"
  type    = "TXT"
  ttl     = 300
  records = [
    "v=DMARC1; p=quarantine; rua=mailto:dmarc-reports@${var.main_dns}; ruf=mailto:dmarc-failures@${var.main_dns}; sp=quarantine; adkim=r; aspf=r"
  ]
}

resource "aws_route53_record" "spf" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.main_dns
  type    = "TXT"
  ttl     = 300
  records = [
    "v=spf1 include:amazonses.com ~all"
  ]
}

resource "aws_route53_record" "dkim" {
  count   = 1
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "${aws_ses_domain_dkim.rustybootcamp.dkim_tokens[count.index]}._domainkey.${var.main_dns}"
  type    = "CNAME"
  ttl     = 300
  records = ["${aws_ses_domain_dkim.rustybootcamp.dkim_tokens[count.index]}.dkim.amazonses.com"]
}
