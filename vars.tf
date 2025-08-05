variable "aws_sso_profile" {
  type        = string
  description = "(string) global project name"
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "project" {
  type    = string
  default = "Lets get Rusty - Bootcamp"
}

variable "owner" {
  type    = string
  default = "ken.esparta"
}

variable "main_dns" {
  type = string
}

variable "jwt_secret" {
  type = string
}

variable "captcha_site_key" {
  type = string
}

variable "captcha_secret_key" {
  type = string
}
