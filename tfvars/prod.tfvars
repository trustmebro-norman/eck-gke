region="us-central1"
subnet_cidr="10.30.10.0/24"
subnet_secondary_gke_service_cidr="10.0.32.0/20"
subnet_secondary_gke_pod_cidr="10.4.0.0/14"
subnet_secondary_gke_master_cidr="172.16.10.0/28"

# K8s objects
# namespaces
namespaces = {
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
# workload identity
workload_identity_mappings = {
    external-dns : {
        name : "external-dns",
        roles : ["roles/dns.admin"],
        kns : "external-dns"
        namespace : "external-dns"
    }
    es-node: {
        name : "es-node",
        roles : ["roles/storage.folderAdmin"],
        kns : "default"
        namespace : "default"      
    }    
}

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
        value_files = [
            { name: "escluster-values.yaml.tftpl", values: {} } 
        ]       
    }    
}

