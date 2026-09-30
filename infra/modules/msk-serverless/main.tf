# This module is a migration starting point, not part of the initial lab.
# MSK Serverless requires private subnets, IAM access control, and a client-security
# configuration. Those production requirements are intentionally isolated from the
# inexpensive public-subnet EC2 lab.
variable "project_name" { type = string }
variable "client_subnet_ids" { type = list(string) }
variable "security_group_ids" { type = list(string) }

resource "aws_msk_serverless_cluster" "this" {
  cluster_name = "${var.project_name}-msk"
  vpc_config {
    subnet_ids         = var.client_subnet_ids
    security_group_ids = var.security_group_ids
  }
  client_authentication { sasl { iam { enabled = true } } }
}

output "bootstrap_brokers_sasl_iam" { value = aws_msk_serverless_cluster.this.bootstrap_brokers_sasl_iam }
