locals {
  tags = {
    Project     = var.project_name
    Environment = "lab"
    Owner       = var.owner
    ManagedBy   = "terraform"
    AutoDestroy = "required"
  }
}

module "network" {
  source       = "../../modules/network"
  project_name = var.project_name
  allowed_cidr = var.allowed_cidr
}

module "kms" {
  source       = "../../modules/kms"
  project_name = var.project_name
}

module "lake_storage" {
  source       = "../../modules/lake-storage"
  project_name = var.project_name
  kms_key_arn  = module.kms.key_arn
}

module "rds" {
  source             = "../../modules/rds-postgres"
  project_name       = var.project_name
  subnet_ids         = module.network.subnet_ids
  vpc_id             = module.network.vpc_id
  ec2_security_group = module.network.ec2_security_group_id
  kms_key_arn        = module.kms.key_arn
  db_name            = var.db_name
  db_username        = var.db_username
}

module "ec2_kafka" {
  source              = "../../modules/ec2-kafka"
  project_name        = var.project_name
  subnet_id           = module.network.subnet_id
  security_group_id   = module.network.ec2_security_group_id
  instance_type       = var.ec2_instance_type
  lake_bucket_name    = module.lake_storage.bucket_name
  kms_key_arn         = module.kms.key_arn
  database_secret_arn = module.rds.password_parameter_arn
  database_endpoint   = module.rds.endpoint
  database_name       = var.db_name
  database_username   = var.db_username
}

module "observability" {
  source           = "../../modules/observability"
  project_name     = var.project_name
  budget_email     = var.budget_email
  budget_limit_usd = var.budget_limit_usd
}
