region="us-central1"
subnet_cidr="10.30.10.0/24"
subnet_secondary_gke_service_cidr="10.0.32.0/20"
subnet_secondary_gke_pod_cidr="10.4.0.0/14"
subnet_secondary_gke_master_cidr="172.16.10.0/28"

# K8s secrets

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
}

