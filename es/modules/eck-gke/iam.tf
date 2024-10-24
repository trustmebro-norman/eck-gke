

locals {
  iam_subnet_role_bindings = {
    "${var.prefix}-es-subnet" : {
      role : "roles/compute.networkUser",
      members : [
        "serviceAccount:service-${data.google_project.default.number}@container-engine-robot.iam.gserviceaccount.com",
        "serviceAccount:${data.google_project.default.number}@cloudservices.gserviceaccount.com",
      ]
    }
  }
  iam_role_bindings = {
    "roles/compute.securityAdmin" = [
      "serviceAccount:service-${data.google_project.default.number}@container-engine-robot.iam.gserviceaccount.com",
    ]
  }
}

resource "google_compute_subnetwork_iam_binding" "gke_subnet" {
  for_each = { for k, v in local.iam_subnet_role_bindings: k => v if local.norman_want_it }

  project = var.project_id
  region  = var.region

  subnetwork = each.key
  role       = each.value.role

  members = each.value.members
}

module "storage_iam" {
  count = local.norman_want_it ? 1 : 0
  source  = "terraform-google-modules/iam/google//modules/projects_iam"
  version = "~> 8.0"

  projects = [var.project_id]

  bindings = local.iam_role_bindings
}