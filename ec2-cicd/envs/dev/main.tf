terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

module "ec2_app" {
  source = "../../modules/ec2-app"

  project           = var.project
  env               = "dev"
  region            = var.region
  instance_type     = var.instance_type
  ami_id            = var.ami_id
  key_name          = var.key_name
  admin_cidrs       = var.admin_cidrs
  app_port          = var.app_port
  startup_s3_bucket = var.startup_s3_bucket
  startup_s3_key    = var.startup_s3_key
}