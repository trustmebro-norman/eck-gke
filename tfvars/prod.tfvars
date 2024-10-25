project_id = "norman-not-normal"
prefix= "prod"
region="us-central1"
subnet_cidr="10.30.10.0/24"
subnet_secondary_gke_service_cidr="10.0.32.0/20"
subnet_secondary_gke_pod_cidr="10.4.0.0/14"
subnet_secondary_gke_master_cidr="172.16.10.0/28"

# GKE node config
node_pool_configs = [
    {
      purpose              = "es"
      machine_type         = "n2-standard-32" # 16 core, 128 GB mem
      min_count            = 2
      max_count            = 15
      disk_size_gb         = 4096
      initial_node_count   = 5
    }
]

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

