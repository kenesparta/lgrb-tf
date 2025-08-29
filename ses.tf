resource "aws_ses_domain_identity" "rustybootcamp" {
  domain = var.main_dns
}

resource "aws_ses_domain_dkim" "rustybootcamp" {
  domain = aws_ses_domain_identity.rustybootcamp.domain
}

resource "aws_ses_domain_mail_from" "rustybootcamp" {
  domain           = aws_ses_domain_identity.rustybootcamp.domain
  mail_from_domain = "mail.${var.main_dns}"
}

resource "aws_ses_email_identity" "kenesparta_gmail" {
  email = "kenesparta@gmail.com"
}

resource "aws_ses_configuration_set" "rustybootcamp" {
  name = "rustybootcamp-config-set"

  delivery_options {
    tls_policy = "Require"
  }
}

resource "aws_ses_identity_policy" "rustybootcamp_policy" {
  identity = aws_ses_domain_identity.rustybootcamp.arn
  name     = "rustybootcamp-ses-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail"
        ]
        Resource = aws_ses_domain_identity.rustybootcamp.arn
        Condition = {
          StringEquals = {
            "ses:FromAddress" = "auth@rustybootcamp.xyz"
          }
        }
      }
    ]
  })
}
