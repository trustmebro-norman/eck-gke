data "google_project" "default" {
  project_id = var.project_id
}

data "google_client_config" "default" {}