variable "project_name" { type = string }
variable "subnet_ids" { type = list(string) }
variable "vpc_id" { type = string }
variable "ec2_security_group" { type = string }
variable "kms_key_arn" { type = string }
variable "db_name" { type = string }
variable "db_username" { type = string }

resource "random_password" "db" {
  length  = 32
  special = false
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.project_name}-db"
  subnet_ids = var.subnet_ids
}

resource "aws_security_group" "rds" {
  name_prefix = "${var.project_name}-rds-"
  vpc_id      = var.vpc_id
  ingress {
    description     = "PostgreSQL only from Kafka/generator EC2"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.ec2_security_group]
  }
}

resource "aws_db_parameter_group" "this" {
  name_prefix = "${var.project_name}-pg-"
  family      = "postgres16"
  parameter {
    name         = "rds.logical_replication"
    value        = "1"
    apply_method = "pending-reboot"
  }
}

resource "aws_db_instance" "this" {
  identifier                   = var.project_name
  engine                       = "postgres"
  engine_version               = "16"
  instance_class               = "db.t4g.micro"
  allocated_storage            = 20
  max_allocated_storage        = 25
  storage_type                 = "gp3"
  storage_encrypted            = true
  kms_key_id                   = var.kms_key_arn
  db_name                      = var.db_name
  username                     = var.db_username
  password                     = random_password.db.result
  port                         = 5432
  db_subnet_group_name         = aws_db_subnet_group.this.name
  vpc_security_group_ids       = [aws_security_group.rds.id]
  parameter_group_name         = aws_db_parameter_group.this.name
  publicly_accessible          = false
  multi_az                     = false
  backup_retention_period      = 0
  deletion_protection          = false
  skip_final_snapshot          = true
  auto_minor_version_upgrade   = false
  apply_immediately            = true
  performance_insights_enabled = false
}

resource "aws_ssm_parameter" "db_password" {
  name   = "/${var.project_name}/database/password"
  type   = "SecureString"
  key_id = var.kms_key_arn
  value  = random_password.db.result
}

output "endpoint" { value = aws_db_instance.this.address }
output "password_parameter_arn" { value = aws_ssm_parameter.db_password.arn }
