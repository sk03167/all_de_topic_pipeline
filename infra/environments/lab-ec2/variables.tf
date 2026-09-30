variable "aws_region" { type = string }
variable "project_name" {
  type    = string
  default = "olist-lakehouse-lab"
}
variable "owner" { type = string }
variable "allowed_cidr" {
  description = "Your public IPv4 CIDR, for example 203.0.113.10/32."
  type        = string
}
variable "budget_email" { type = string }
variable "budget_limit_usd" {
  type    = number
  default = 15
  validation {
    condition     = var.budget_limit_usd >= 5
    error_message = "Set a realistic non-zero budget, at least USD 5."
  }
}
variable "db_name" {
  type    = string
  default = "olist"
}
variable "db_username" {
  type    = string
  default = "olist_admin"
}
variable "ec2_instance_type" {
  type    = string
  default = "t3.medium"
}
