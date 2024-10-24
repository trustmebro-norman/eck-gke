locals {
  node_pool_common_config = {
    autoscaling = true
    node_locations = join(",", [
      for i in ["a", "b", "c"] : "${var.region}-${i}"
    ])
    local_ssd_count      = 0
    disk_type            = "pd-standard"
    image_type           = "COS_CONTAINERD"
    logging_variant      = "DEFAULT"
    auto_repair          = true
    auto_upgrade         = true
    service_account      = "${data.google_project.default.number}-compute@developer.gserviceaccount.com"
    gpu_sharing_strategy = "TIME_SHARING"
  }
}

module "gke" {
  count   = local.norman_want_it ? 1 : 0
  source  = "terraform-google-modules/kubernetes-engine/google//modules/private-cluster"
  version = "33.1.0"

  name       = "${var.prefix}-cluster"
  project_id = var.project_id
  region     = var.region
  zones = [
    for i in ["a", "b", "c"] : "${var.region}-${i}"
  ]
  network                         = "${var.prefix}-es-vpc"
  subnetwork                      = "${var.prefix}-es-subnet"
  ip_range_pods                   = "${var.prefix}-es-pod-cidr"
  ip_range_services               = "${var.prefix}-es-service-cidr"
  http_load_balancing             = true # enable for auto create ALB when using ingress controller
  horizontal_pod_autoscaling      = true # for hpa
  gce_pd_csi_driver               = true # persistent volume support
  enable_private_nodes            = true
  gcp_public_cidrs_access_enabled = true # public access allowed by GCP services

  node_pools = [
    for k, v in var.node_pool_configs : merge(local.node_pool_common_config, {
      name               = "${var.prefix}-${v.purpose}"
      machine_type       = v.machine_type
      min_count          = v.min_count
      max_count          = v.max_count
      disk_size_gb       = v.disk_size_gb
      initial_node_count = v.initial_node_count
    })
  ]

  node_pools_labels = {
    all = {}
    "${var.prefix}-es" = {
      es-node-pool = true
    }
  }

  node_pools_tags = {
    all = []
    "${var.prefix}-es" = [
      "es-node-pool",
    ]
  }

  depends_on = [
    google_compute_subnetwork_iam_binding.gke_subnet,
    module.storage_iam,
    module.vpc,
  ]
}