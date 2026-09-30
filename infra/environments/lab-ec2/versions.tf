terraform {
  required_version = ">= 1.6.0"

  backend "s3" {
    bucket       = "olist-lakehouse-tfstate-930628638871-ap-south-1"
    key          = "lab-ec2/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    kms_key_id   = "arn:aws:kms:ap-south-1:930628638871:key/9c13d1de-c9e1-4001-b1ac-94bbdc0741e1"
    use_lockfile = true
    profile      = "olist-lakehouse-terraform-deployer"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.tags
  }
}
