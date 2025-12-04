
provider "aws" {
  region = "us-east-1"
  }
locals {
  name_prefix     = "Janhvi_Singh_"  
  vpc_cidr        = "10.0.0.0/16"
  azs             = ["us-east-1a", "us-east-1b"] 
 
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.10.0/24", "10.0.11.0/24"]
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.5.3" 

  name = "${local.name_prefix}VPC"
  cidr = local.vpc_cidr
  
  azs = local.azs
  
  public_subnets  = local.public_subnets
  private_subnets = local.private_subnets
  
  enable_nat_gateway = true      
  single_nat_gateway = true      
  enable_dns_hostnames = true

  tags = {
    Name        = "${local.name_prefix}VPC"
    Project     = "Internship Assessment"
  }
}