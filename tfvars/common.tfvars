project_id = "norman-not-normal"

# K8s common
# namespaces
namespaces = {
    external-dns = {
        name = "external-dns",
    },
    cert-manager = {
        name= "cert-manager",
    },
}
# workload identity
workload_identity_mappings = {
    external-dns = {
        name = "external-dns",
        roles = ["roles/dns.admin"],
        kns = "external-dns"
        namespace = "external-dns"
    }
    es-node = {
        name = "es-node",
        roles = ["roles/storage.folderAdmin"],
        kns = "default"
        namespace = "default"      
    }    
}
# eck-gke common helm chart values
# will be merged in helm_releases at Terraform runtime
# to keep dev.tfvars and prod.tfvars dry
eck_helm_common_values = {
    cluster_name = "common"
    elastic_version = "8.15.3"
    pdb_min_available = 2
    storage_class = "standard-rwo"
    region = "us-central1"
    hpa_enabled = true
    # master nodeSet
    enable_master_node = true
    master_count = 1
    master_cpu_request = "250Mi"
    master_mem_request = "1Gi"
    master_cpu_limit = 1
    master_mem_limit = "1Gi"                
    master_storage = "50Gi"
    master_hpa_enabled = false
    # data_hot nodeSet
    enable_data_hot_node = true
    data_hot_count = 3
    data_hot_cpu_request = 1
    data_hot_mem_request = "4Gi"
    data_hot_cpu_limit = 2
    data_hot_mem_limit = "8Gi"                
    data_hot_storage = "500Gi"
    data_hot_hpa_enabled = true
    # data_warm nodeSet
    enable_data_warm_node = false
    data_warm_count = ""
    data_warm_cpu_request = ""
    data_warm_mem_request = ""
    data_warm_cpu_limit = ""
    data_warm_mem_limit = ""
    data_warm_storage = ""
    data_warm_hpa_enabled = false               
    # data_cold nodeSet
    enable_data_cold_node = false
    data_cold_count = ""
    data_cold_cpu_request = ""
    data_cold_mem_request = ""
    data_cold_cpu_limit = ""
    data_cold_mem_limit = ""                
    data_cold_storage = ""
    data_cold_hpa_enabled = false
    # kibana
    kibana_enabled = true
    kibana_count = 1
    kibana_service_type = "ClusterIP"
    kibana_cpu_request = "250Mi"
    kibana_mem_request = "1Gi"
    kibana_cpu_limit = "500Mi"
    kibana_mem_limit = "2Gi"
    kibana_ingress_enabled = true
    kibana_ingress_class = "gce"
    root_domain = "normanguys.dev"
    use_externaldns = true
}