terraform {
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