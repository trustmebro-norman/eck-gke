module "vpc" {
  count   = local.norman_want_it ? 1 : 0
  source  = "terraform-google-modules/network/google"
  version = "~> 9.3"

  project_id   = var.project_id
  network_name = "${var.prefix}-es-vpc"
  routing_mode = "GLOBAL"

  subnets = [
    {
      subnet_name           = "${var.prefix}-es-subnet"
      subnet_ip             = "${var.subnet_cidr}"
      subnet_region         = "${var.region}"
      subnet_private_access = "true"
    },
  ]

  secondary_ranges = {
    "${var.prefix}-es-subnet" = [
      {
        range_name    = "${var.prefix}-es-service-cidr"
        ip_cidr_range = "${var.subnet_secondary_gke_service_cidr}"
      },
      {
        range_name    = "${var.prefix}-es-pod-cidr"
        ip_cidr_range = "${var.subnet_secondary_gke_pod_cidr}"
      },
    ]
  }
}
