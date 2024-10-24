resource "google_storage_bucket" "terraform_state" {
  name     = "normankernel-not-normal-tf-backend"
  location = "us-central1"
  project  = "norman-not-normal"

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }
}