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
  depends_on       = [module.gke]
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

resource "kubernetes_namespace_v1" "this" {
  for_each = { for k, ns in var.namespaces : k => ns if local.norman_want_it }

  metadata {
    name = each.value.name
  }
}

resource "google_service_account" "this" {
  for_each = { for k, v in var.workload_identity_mappings : k => v.name if local.norman_want_it }

  account_id = each.value
}

resource "google_project_iam_member" "this" {
  for_each = merge([
    for k, v in var.workload_identity_mappings : {
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
  for_each = { for k, v in var.workload_identity_mappings : k => v if local.norman_want_it }

  metadata {
    name      = each.value.name
    namespace = each.value.namespace
    annotations = {
      "iam.gke.io/gcp-service-account" = google_service_account.this[each.value.name].email
    }
  }

  depends_on = [kubernetes_namespace_v1.this]
}

resource "google_project_iam_member" "workload_identity-role" {
  for_each = { for k, v in var.workload_identity_mappings : k => v if local.norman_want_it }

  project = var.project_id
  role    = "roles/iam.workloadIdentityUser"
  member  = "serviceAccount:${var.project_id}.svc.id.goog[${each.value.namespace}/${each.value.name}]"

  depends_on = [kubernetes_service_account.this]
}

resource "helm_release" "main" {
  for_each = { for k, v in var.helm_releases : k => v if local.norman_want_it }

  name          = each.value.release_name
  repository    = try(each.value.repo, null) # support local chart
  chart         = each.value.chart
  version       = try(each.value.chart_version, null) # support local chart
  namespace     = try(each.value.namespace, "default")
  reset_values  = try(each.value.reset_values, false)
  force_update  = try(each.value.force_update, false)  # force update resources under helm release
  recreate_pods = try(each.value.recreate_pods, false) # force update pods based on strategy (re-create/rolling-update)

  values = [
    for k, v in each.value.value_files : 
      try(each.value.merge_with_common, false)
      # try to merge var.eck_helm_common_values with override version, by default return var.eck_helm_common_values
      ? templatefile("${path.module}/helms/${v.name}", try(merge(var.eck_helm_common_values, v.values), var.eck_helm_common_values))
      # otherwise use bare values
      : templatefile("${path.module}/helms/${v.name}", try(v.values, null))
  ]

  dynamic "set" {
    for_each = {
      for k, v in try(each.value.overriden_values, []) : k => v if try(!v.is_sensitive, false) && try(!v.is_list, false)
    }
    iterator = set_default

    content {
      name  = set_default.value.name
      value = set_default.value.value
      type  = try(set_default.value.type, "string")
    }
  }

  depends_on = [ 
    kubernetes_service_account.this
  ]
}

