resource "time_sleep" "gke_check_readiness" {
  count = local.norman_want_it ? 1 : 0

  create_duration = "30s"
  provisioner "local-exec" {
    command = "gcloud container clusters get-credentials ${var.prefix}-cluster --region ${var.region} --project ${var.project_id}"
  }
  depends_on = [module.gke]
}

resource "time_sleep" "gke_destruction_cleanup" {
  count = local.norman_want_it ? 1 : 0

  destroy_duration = "180s"
  depends_on = [module.gke]
}

provider "kubernetes" {
  host  = "https://${module.gke[0].endpoint}"
  token = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(
    module.gke[0].ca_certificate,
  )
}

provider "helm" {
  kubernetes {
    host  = "https://${module.gke[0].endpoint}"
    token = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(
      module.gke[0].ca_certificate,
    )
  }
}

# workload identity
locals {
  namespace = {
    external-dns: {
      name: "external-dns",
    },
    cert-manager: {
      name: "cert-manager",
    },
    elastic-system: {
      name: "elastic-system",
    },
    monitoring: {
      name: "monitoring",
    }
  }
  workload_identity_mappings = {
    external-dns : {
      name : "external-dns",
      roles : ["roles/dns.admin"],
      kns : "external-dns"
      namespace : "external-dns"
    }    
  }
}

resource "kubernetes_namespace_v1" "this" {
  for_each = { for k, ns in local.namespace : k => ns if local.norman_want_it }

  metadata {
    name = each.value.name
  }
}

resource "google_service_account" "this" {
  for_each = { for k, v in local.workload_identity_mappings : k => v.name if local.norman_want_it }

  account_id = each.value
}

resource "google_project_iam_member" "this" {
  for_each = merge([
    for k, v in local.workload_identity_mappings : {
      for role in v.roles : "${v.name}-${role}" => {
        name : v.name,
        kns : v.kns,
        namespace : v.namespace,
        role : role
      }
    } if local.norman_want_it
  ]...)
  project = var.project_id
  role    = each.value.role
  member  = "serviceAccount:${google_service_account.this[each.value.name].email}"
}

resource "kubernetes_service_account" "this" {
  for_each = { for k, v in local.workload_identity_mappings : k => v if local.norman_want_it }

  metadata {
    name      = each.value.name
    namespace = each.value.namespace
    annotations = {
      "iam.gke.io/gcp-service-account" = google_service_account.this[each.value.name].email
    }
  }

  depends_on = [ kubernetes_namespace_v1.this ]
}

resource "google_project_iam_member" "workload_identity-role" {
  for_each = { for k, v in local.workload_identity_mappings : k => v if local.norman_want_it }

  project = var.project_id
  role    = "roles/iam.workloadIdentityUser"
  member  = "serviceAccount:${var.project_id}.svc.id.goog[${each.value.namespace}/${each.value.name}]"

  depends_on = [kubernetes_service_account.this]
}


#  helm releases
locals {
  k8s_secrets = {}
  helm_releases = {}
}

