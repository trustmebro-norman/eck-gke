variable "project_id" {
  description = "The GCP project ID to deploy into"
}

variable "prefix" {
  description = "Prefix to be used for all resources"
}

variable "region" {
  description = "GCP region to deploy into"
}

variable "subnet_cidr" {
  description = "VPC subnet CIDR"
}

variable "subnet_secondary_gke_service_cidr" {
  description = "GKE secondary range for services"
}

variable "subnet_secondary_gke_pod_cidr" {
  description = "GKE secondary range for pods"
}

variable "subnet_secondary_gke_master_cidr" {
  description = "GKE secondary range for pods"
}

variable "namespaces" {
  description = "K8s namespace to create"
}

variable "workload_identity_mappings" {
  description = "workload identity to create for mappings betweeen gcs and ksa"
}

variable "helm_releases" {
  description = "helm releases mapping including managed workloads"
}

variable "node_pool_configs" {
  description = "config list for node_pool variants"
}