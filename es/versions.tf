terraform {
  required_version = ">=1.5.7"

  backend "gcs" {
    bucket = "normankernel-not-normal-tf-backend"
    prefix = "es/backend/terraform.tfstate"    
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.64, < 7"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 4.64, < 7"
    }
  }
}

provider "google" {
  project = "norman-not-normal"
  region  = "us-central1"
}