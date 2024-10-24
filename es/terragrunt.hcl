remote_state {
  backend = "gcs"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket = "normankernel-not-normal-tf-backend"
    prefix = "es/${path_relative_to_include()}/terraform.tfstate"
  }
}

generate "provider" {
  path = "versions.tf"
  if_exists = "overwrite_terragrunt"
  contents = <<EOF
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.64, < 7"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 4.64, < 7"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.25.2"
    }
    time = {
      source = "hashicorp/time"
      version = "0.12.1"
    }    
  }    
}
provider "google" {
  project = "norman-not-normal"  
  region = "us-central1"
}
EOF
}