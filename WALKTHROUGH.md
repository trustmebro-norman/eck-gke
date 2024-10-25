## Install Terragrunt in CloudShell
- This repository aim to create GKE private cluster which has public endpoint allowed from GCP service so It is recommended to be ran on CloudShell
- Navigate to `scripts` folder and exec `./install_terragrunt_linux_amd64.sh` to quickly grab Terragrunt on CloudShell

## Backend generation
- This repository is controlled centrally by Terragrunt wrapper and Terraform. So all Terraform configuration (code, CLI args, tfvars) for root module in each environment are defined by `terragrunt.hcl`
- Simple Terragrunt visual of this repo should be like
```
.
├── backend.tf # init gcs bucket as remote backend here
└── versions.tf # init provider for remote backend
├── dev
│   └── terragrunt.hcl # leaf terragrunt config for dev environment
├── prod
│   ├── backend.tf
│   ├── terragrunt.hcl # leaf terragrunt config for prod environment
│   └── versions.tf
├── modules
│   └── eck-gke
│       ├── data.tf
│       ├── gke.tf
│       ├── helm.tf
│       ├── iam.tf
│       ├── inputs.tf
│       ├── locals.tf
│       ├── network.tf
│       └── outputs.tf
├── terragrunt.hcl # root terragrunt config to define set of providers and remote backend
```

## Project structure
```
.
├── backend.tf
├── dev
│   └── terragrunt.hcl
├── helms
│   ├── certmanager-csi-values.yaml.tftpl
│   ├── certmanager-values.yaml.tftpl
│   ├── eck-operator-values.yaml.tftpl
│   ├── elastic-cluster
│   │   ├── charts
│   │   ├── Chart.yaml
│   │   ├── templates
│   │   │   ├── certificates.yaml
│   │   │   ├── elasticsearch-hpa.yaml
│   │   │   ├── elasticsearch.yaml
│   │   │   ├── _helpers.tpl
│   │   │   └── kibana.yaml
│   │   └── values.yaml
│   ├── escluster-values.yaml.tftpl
│   ├── externaldns-values.yaml.tftpl
│   └── trustmanager-values.yaml.tftpl
├── modules
│   └── eck-gke
│       ├── data.tf
│       ├── gke.tf
│       ├── helm.tf
│       ├── iam.tf
│       ├── inputs.tf
│       ├── locals.tf
│       ├── network.tf
│       └── outputs.tf
├── WALKTHROUGH.md
├── prod
│   ├── backend.tf
│   ├── terragrunt.hcl
│   └── versions.tf
├── README.md
├── scripts
│   ├── install_terragrunt_linux_amd64.sh
│   ├── node_logs.sh
│   └── prepare.sh
├── terragrunt.hcl
├── tfvars
│   ├── common.tfvars
│   ├── dev.tfvars
│   └── prod.tfvars
└── versions.tf
```

## Terragrunt runtime
- Backend, providers generation:
```terraform
# root terragrunt.hcl

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

# prod/terragrunt.hcl inherit root configuration

include "root" {
  path = find_in_parent_folders()
}
```

- Terraform root module resource generation
```
# prod/terragrunt.hcl initiates module eck-gke without Terraform module block

terraform {
  source = "../modules/eck-gke"

  ...
}
```
- Terraform CLI flags
```terraform
# prod/terragrunt.hcl initiates flags as CLI args. Eg: It grab 
common.tfvars and prod.tfvars from parent tfvars dir to init inputs for production (Terraform module, Helm, etc)

  extra_arguments "common_vars" {
    commands = get_terraform_commands_that_need_vars()

    arguments = [
      "-var-file=${get_parent_terragrunt_dir()}/tfvars/common.tfvars",
    ]

    optional_var_files = [
      "${get_parent_terragrunt_dir()}/tfvars/prod.tfvars"
    ]
  }
```
- Terraform CLI hook
```terraform
# prod/terragrunt.hcl trigger hook before actual running commands. Eg: Copy helm values into Terragrunt cache

  before_hook "copy_vars" {
    commands = get_terraform_commands_that_need_vars()

    execute  = ["cp", "-r", "${dirname(find_in_parent_folders())}/helms/", "."]
  }
```

## Terraform tfvars
- `common.tfvars` defines common configuration across environments. Just like k8s namespaces, workload identity mappings and main application `eck-gke` common Helm values
- `prod.tfvars` or `dev.tfvars` will define environment specific configurations which might be used for infrastructures and Helm charts (via `.tftpl` files)
- `prod.tfvars` or `dev.tfvars` will take precedences over `common.tfvars`

## Terraform main application/module: eck-gke
- Resource creation condition:
```
locals {
  norman_want_it = true # destroy everything in oneshot
}
```
### Project and network: 
For instant demo, we might skip organization/folder/project configuration (landing zones). We use only one project without `VPC sharing` as the simplest approach

### IAM:
We need both role `roles/compute.networkUser` (for using subnet) and `roles/compute.securityAdmin` (to automatically create firewall rules) bound to GKE service account

### GKE:
- Control plane specs:
    - regional: better HA
    - http_load_balancing: to create GCP Http LB from service type LoadBalancer
    - horizontal_pod_autoscaling: better HA
    - gce_pd_csi_driver: install CSI PD for PVCs from ElasticSeach
    - enable_private_nodes: disable node public IPs - better secure
    - gcp_public_cidrs_access_enabled: Allow traffic from GCP CIDR to controlplan public IP
- Node pool specs:
    - multiple node pools support: yes
    - node pool final configuration considered by merging environment specific and common config
```terraform
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
...
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
...
```

### K8s resources
- Namespace creation: Namespace will be created outside any Helm chart for better control (annotatation, label, resource management, etc)
```
resource "kubernetes_namespace_v1" "this" {
  for_each = { for k, ns in var.namespaces : k => ns if local.norman_want_it }

  metadata {
    name = each.value.name
  }
}
```

- K8s service account creation: With namespace, K8s service accounts are mandatory to create `Workload Identity Mappings`. So we create K8s service accounts by `Workload Identity config`
```
resource "kubernetes_service_account" "this" {
  for_each = { for k, v in var.workload_identity_mappings : k => v if local.norman_want_it }

  ...
}

resource "google_service_account" "this" {
  for_each = { for k, v in var.workload_identity_mappings : k => v.name if local.norman_want_it }

  ...
}

resource "google_project_iam_member" "workload_identity-role" {
  for_each = { for k, v in var.workload_identity_mappings : k => v if local.norman_want_it }

  ...
}

# IAM role bindings for GCP sa
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

  ...
}

# IAM role bindings for Workload Identity Mappings
resource "google_project_iam_member" "workload_identity-role" {
  for_each = { for k, v in var.workload_identity_mappings : k => v if local.norman_want_it }

  ...
}
```
- Workload Identity will be used for these use cases in this repo:
    - Delegate Cloud DNS zone add records to external-dns service account
    - Allow elasticsearch service account to register automated snapshots which uses GCS buckets


### Helm resources:
- Consider this from `tfvars/prod.tfvars`
```
# Helm releases
helm_releases = {
    # eck-operator
    eck-operator = {
        release_name = "eck-operator"
        repo = "https://helm.elastic.co"
        chart = "eck-operator"
        chart_version = "2.14.0"
        namespace = "default"
        value_files = [ 
            { name: "eck-operator-values.yaml.tftpl", values: {} }
        ]
    }
    # certmanager
    certmanager = {
        release_name = "certmanager"
        repo = "https://charts.jetstack.io"
        chart = "cert-manager"
        chart_version = "1.16.1"
        namespace = "cert-manager"
        value_files = [ 
            { name: "certmanager-values.yaml.tftpl", values: {} }
        ]
    }
    # certmanager-csi
    certmanager-csi = {
        release_name = "certmanager-csi"
        repo = "https://charts.jetstack.io"
        chart = "cert-manager-csi-driver"
        chart_version = "0.10.1"
        namespace = "cert-manager"
        value_files = [ 
            { name: "certmanager-csi-values.yaml.tftpl", values: {} }
        ]
    }    
    # trustmanager
    trustmanager = {
        release_name = "trustmanager"
        repo = "https://charts.jetstack.io"
        chart = "trust-manager"
        chart_version = "0.12.0"
        namespace = "cert-manager"
        value_files = [
            { name: "trustmanager-values.yaml.tftpl", values: {} } 
        ]
    }
    # externaldns
    externaldns = {
        release_name = "externaldns"
        repo = "https://kubernetes-sigs.github.io/external-dns/"
        chart = "external-dns"
        chart_version = "1.15.0"
        namespace = "external-dns"
        value_files = [
            { name: "externaldns-values.yaml.tftpl", values: {
                root_domain: "normanguys.dev"
            }} 
        ]       
    }
    # elasticsearch cluster, self-managed application
    escluster = {
        release_name = "esprod"
        chart = "./helms/elastic-cluster"
        chart_version = "1.0.1"
        namespace = "default"
        force_update = true
        recreate_pods = true
        merge_with_common = true
        value_files = [
            { name = "escluster-values.yaml.tftpl", values = {
                cluster_name = "prod"
                pdb_min_available = 5
                region = "us-central1"
                # master nodeSet
                enable_master_node = true
                master_count = 3
                master_cpu_request = 4
                master_mem_request = "8Gi"
                master_cpu_limit = 4
                master_mem_limit = "8Gi"                
                master_storage = "100Gi"
                master_hpa_enabled = false
                # data_hot nodeSet
                enable_data_hot_node = true
                data_hot_count = 3
                data_hot_cpu_request = 8
                data_hot_mem_request = "32Gi"
                data_hot_cpu_limit = 8
                data_hot_mem_limit = "32Gi"                
                data_hot_storage = "500Gi"
                data_hot_hpa_enabled = true
                # data_warm nodeSet
                enable_data_warm_node = true
                data_warm_count = 2
                data_warm_cpu_request = 4
                data_warm_mem_request = "16Gi"
                data_warm_cpu_limit = 4
                data_warm_mem_limit = "16Gi"
                data_warm_storage = "1000Gi"
                data_warm_hpa_enabled = false               
                # data_cold nodeSet
                enable_data_cold_node = true
                data_cold_count = 2
                data_cold_cpu_request = 2
                data_cold_mem_request = "8Gi"
                data_cold_cpu_limit = 2
                data_cold_mem_limit = "8Gi"                
                data_cold_storage = "2000Gi"
                data_cold_hpa_enabled = false
                # kibana
                kibana_cpu_request = "500Mi"
                kibana_mem_request = "1Gi"
                kibana_cpu_limit = 1
                kibana_mem_limit = "2Gi"
                } 
            } 
        ]
    }    
}
```
- `eck-operator`: Inititates CRDs for ElasticSearch, Kibana, ElasticsearchAutoscaler
- `cert-manager`: To manage lifecycle of ElasticSearch Transport certs, ElasticSearch Http certs, Kibana certs
- `cert-manager-csi`: Allow to mount cert-manager `ClusterIssuer` directly into pods and create inter cert based on dnsNames of Pod.
- `trust-manager`: Bundle CA cert into single `trust` bundle. By default, It will create a configmap contains bundler across K8s namespaces
- `external-dns`: Allow Ingress controller to create Cloud DNS records via Ingress annotations and Workload Identity
- `escluster`: Self-managed Helm where actual application living




