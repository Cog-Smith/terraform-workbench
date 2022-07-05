terraform {
  # backend "s3" {
  #   bucket         = "tf-remote-state-sprovider-backend"
  #   key            = "accounts/backend/terraform.tfstate"
  #   region         = "us-west-2"
  #   encrypt        = true
  #   kms_key_id     = "arn:aws:kms:us-west-2:289031936666:key/a39fdbb8-2a7d-486a-975d-ce551bd40c01"
  #   dynamodb_table = "tf-remote-state-sprovider-locking-table"
  #   profile        = "aws-gl-sandbox"
  # }
}

provider "aws" {
  region  = local.region
  profile = "aws-gl-sandbox"
}

provider "aws" {
  alias   = "replica"
  region  = local.replica_region
  profile = "aws-gl-sandbox"
}

locals {
  region         = "us-west-2"
  replica_region = "us-east-1"  
  tags   = {
    "symplr-environment"    = "test" 
    "symplr-costaccounting" = "it"
    "symplr-pointofcontact" = "monitoring-it-systems@symplr.com"
    "symplr-purpose"        = "terraform deployment testing"          
  }
}

module "backend_test" {
  source        = "../"
  project       = "sprovider"
  force_destroy = true
                            
  providers = {
    aws         = aws
    aws.replica = aws.replica
  }

  tags               = local.tags 
}