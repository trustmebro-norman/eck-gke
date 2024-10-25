## ECK a.k.a ElasticSearch Cloud on Kubernetes

> For better understanding about this repo. Please refer to [WALKTHROUGH](./WALKTHROUGH.md)

## High Availablity Consideration
### Elastics Search Design for resilience (Best practices theory)
  - At least three master-eligible nodes
  - At least two nodes of each role.
  - At least two copies of each shard (one primary and one replica)

### Implementation in K8s (GKE):
> Infrastructure Utilization:
- Regional Control Plane which has smaller chance to absolute collapsed
- Cluster AutoScale (CA) allows cluster scales horizontally across zones
```terraform
# gke.tf

locals {
  node_pool_common_config = {
    autoscaling = true
    node_locations = join(",", [
      for i in ["a", "b", "c"] : "${var.region}-${i}"
    ])
  ...
  }
}

# tfvars/prod.tfvars

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
```
  - NodeAffinity allows pods to be scheduled across zones

```Helm
{{/* Define helper function for affinity config */}}
{{- define "elasticsearch-cluster.affinity" -}}
{{- if .enableAffinity -}}
nodeAffinity:
  requiredDuringSchedulingIgnoredDuringExecution:
    nodeSelectorTerms:
      - matchExpressions:
        - key: topology.kubernetes.io/zone
          operator: In
          values:
          {{- range .zones }}
          - {{ . }}
          {{- end }} 
{{- end -}}
{{- end -}}
```
  - enableTopologySpreadConstraints allows pod to be scheduled evenly across zones
```Helm
{{/* Define helper function for topologySpreadConstraints config */}}
{{- define "elasticsearch-cluster.topologySpreadConstraints" -}}
{{- if .enableTopologySpreadConstraints -}}
- maxSkew: 1
  topologyKey: topology.kubernetes.io/zone
  whenUnsatisfiable: ScheduleAnyway
  nodeAffinityPolicy: Honor
  nodeTaintsPolicy: Honor
  labelSelector:
    matchLabels:
      elasticsearch.k8s.elastic.co/cluster-name={{ .clusterName }}-cluster 
{{- end -}}
{{- end -}}
```
  - PodDisruptionBudgets allows certain number of pods to be available during re-schedule
```Helm
  {{- if .Values.elasticsearch.podDisruptionBudget }}
  podDisruptionBudget:
    spec:
      minAvailable: {{ .Values.elasticsearch.podDisruptionBudget.spec.minAvailable }}
      selector:
        matchLabels:
          elasticsearch.k8s.elastic.co/cluster-name: {{ .Values.elasticsearch.name }}
  {{- end }} 
```
  - Volume Claim Template allows dynamic bindings between pods and Persistent Volumes
```Helm
{{/* Define helper function for volume claim template */}}
{{- define "elasticsearch-cluster.volumeClaimTemplate" -}}
- metadata:
    name: elasticsearch-data
  spec:
    accessModes:
    - ReadWriteOnce
    storageClassName: {{ .storageClass }}
    resources:
      requests:
        storage: {{ .storage }}
{{- end -}}
```

> Multiple nodes/node roles:
- Multiple nodeSet with dynamic configuration
```terraform
...
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
...
```
> LoadBalancing and ingress routing automatically
- ECK, by default create a set of services for multiple purposes and nodeSet definitions (coordinate, transport, master, data_hot, etc)
```
prod-es-cluster-es-hot             ClusterIP   None          <none>        9200/TCP   25h
prod-es-cluster-es-http            ClusterIP   10.0.46.169   <none>        9200/TCP   25h
prod-es-cluster-es-internal-http   ClusterIP   10.0.43.233   <none>        9200/TCP   25h
prod-es-cluster-es-master          ClusterIP   None          <none>        9200/TCP   25h
prod-es-cluster-es-transport       ClusterIP   None          <none>        9300/TCP   25h
```
- Ingress for better traffic management, the `gce` Ingress class allows Kibana ingress to create Cloud DNS record, acquire certificate from Certificate Manager
```Helm
kind: Ingress
metadata:
  name: ${{ .Values.kibana.name }}-ingress
  annotations:
    networking.gke.io/managed-certificates: kibana
    kubernetes.io/ingress.class: ${{ .Values.kibana.ingress.className }}
    {{- if .Values.kibana.ingress.use_externaldns }}
    external-dns.alpha.kubernetes.io/hostname: kibana.${{ .Values.kibana.ingress.root_domain }}
    {{- end }}
```

## Security Consideration
### Infrastructure utilization
- Private nodes without public IPs and SSH
- GKE clusters initiate set of FW rules with the minimum exposure

### GKE platform utilization
- We can use Workload Identity which allow K8s services account act as GCP service account against GPC services. We get rid of using long-live credentials

### Add-ons utilization
- cert-manager and trust-manager allows us to manage lifecycle of CA, Issuers and cert chains in automated ways
- cert-manager-csi allows us to mount Issuers as ephermeral volume which has better security as not exposing certificate as K8s secret. Consider the transport certificate 
```Helm
- name: transport-certs
  csi:
    driver: csi.cert-manager.io
    readOnly: true
    volumeAttributes:
        csi.cert-manager.io/issuer-name: ca-cluster-issuer 
        csi.cert-manager.io/issuer-kind: ClusterIssuer
        csi.cert-manager.io/dns-names: "${POD_NAME}.${POD_NAMESPACE}.svc.cluster.local"
```

### Main application utilization
- ElasticSearch security plugin is enabled by default. This acquires authentication/authorization
- Traffic encrypted between ElasticSearch Node (TransportTLS). We have to create CA, ClusterIssuer from root-ca and mounted to ES node as a volume by cert-manager-csi plugin
```Helm
...
config
  {{- if .enableTransportTLS | default true  -}}
  # transport TLS
  xpack.security.transport.ssl.enabled: true
  xpack.security.transport.ssl.key: /usr/share/elasticsearch/config/cert-manager-certs/tls.key
  xpack.security.transport.ssl.certificate: /usr/share/elasticsearch/config/cert-manager-certs/tls.crt
  {{- end -}}

podTemplate:
  spec:
    containers:
    - name: elasticsearch
      {{- if $.Values.elasticsearch.common.config.enableTransportTLS }}
      volumeMounts:
      {{- include "elasticsearch-cluster.extraVolumeMounts" (dict "enableTLS" $.Values.elasticsearch.common.config.enableTransportTLS) | nindent 10 }} 
      {{- end }}    
    volumes:
    {{- if .enableTLS -}}
    - name: transport-certs
      csi:
        driver: csi.cert-manager.io
        readOnly: true
        volumeAttributes:
            csi.cert-manager.io/issuer-name: ca-cluster-issuer 
            csi.cert-manager.io/issuer-kind: ClusterIssuer
            csi.cert-manager.io/dns-names: "${POD_NAME}.${POD_NAMESPACE}.svc.cluster.local"
    {{- end -}}    
```
- Traffic encrypted between ES node and client (Kibana):
  - Consider the ES config. The ssl.certificate will be trusted by its ca.crt which packaged into trust configmap
```Helm
{{- if .enableHttpTLS | default true -}}
# http TLS enabled. Es CA cert should be mounted to client trust store (Eg: Kibana)
xpack.security.http.ssl.enabled: true
xpack.security.http.ssl.key: /usr/share/elasticsearch/config/cert-manager-certs/tls.key
xpack.security.http.ssl.certificate: /usr/share/elasticsearch/config/cert-manager-certs/tls.crt 
{{- end -}}
```
  - And consider Kibana config
```Helm
spec:
  config:
    {{- if .enableHttpTLS | default true -}}
    elasticsearch.hosts: https://{{ .clusterName }}-es-http:9200
    elasticsearch.ssl.certificateAuthorities: $KBN_PATH_CONF/cert-manager-certs/elasticsearch-ca.pem
    elasticsearch.username: elastic
    {{- end -}}

  podTemplate:
    spec:
      volumes:
        {{- if .enableHttpTLS | default true -}}
        - name: elasticsearch-ca-cert
          configMap:
            name: trust
        {{- end -}}
      containers:
      - name: kibana
        volumeMounts:
        {{- if .enableHttpTLS | default true -}}
        - name: elasticsearch-ca-cert
          mountPath: $KBN_PATH_CONF/cert-manager-certs/elasticsearch-ca.pem
        {{- end -}}
```
- Traffic encrypted between ingress and kibana as backend. We have to create Kibana inter-cert from root-ca ClusterIssuers
  - Consider the Kibana certificate, this wil create the following secret as certificate name which contains three keys: ca.crt, tls.crt, tls.key
```Helm
{{- if and ( .Values.kibana.enableHttpTLS | default true ) ( .Values.kibana.enableIngressTLS | default true ) }}
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: {{ .Values.kibana.cert_name }}
spec:
  commonName: selfsigned-ca
  secretName: {{ .Values.kibana.cert_name }}
  privateKey:
    algorithm: ECDSA
    size: 256
  dnsNames:
  - {{ .Values.kibana.name }}-kb-http
  - {{ .Values.kibana.name }}-kb-http.{{ .Values.global.namespace }}
  - {{ .Values.kibana.name }}-kb-http.{{ .Values.global.namespace }}.svc.cluster.local
  issuerRef:
    name: cluster-issuer
    kind: ClusterIssuer
    group: cert-manager.io
{{- end }}
```
  - Consider Kibana config to import tls.crt and tls.key from mounting secret as volume
```Helm
spec:
  config:
    {{- if .enableIngressTLS | default true  -}}
    server.ssl.enabled: true
    server.ssl.certificate: $KBN_PATH_CONF/cert-manager-certs/kibana/tls.crt
    server.ssl.key: $KBN_PATH_CONF/cert-manager-certs/kibana/tls.key
    {{- end -}}

  podTemplate:
    spec:
      volumes:
      {{- if .enableIngressTLS | default true -}}
      - name: kibana-cert
        secret:
          secretName: kibana-cert
      {{- end -}}
      containers:
      - name: kibana
        volumeMounts:
        {{- if .enableIngressTLS | default true -}}
        - name: kibana-cert
          subPath: tls.crt
          mountPath: $KBN_PATH_CONF/cert-manager-certs/kibana/tls.crt
        - name: kibana-cert
          subPath: tls.key
          mountPath: $KBN_PATH_CONF/cert-manager-certs/kibana/tls.key  
        {{- end -}}
```
  - Consider the ingress config to mount ca.crt to backend (to trust Kibana cert)
```Helm
spec:
  {{- if .Values.kibana.enableIngressTLS | default true }}
  tls:
  - hosts:
      - kibana.${{ .Values.kibana.ingress.root_domain }}
    secretName: {{ .Values.kibana.cert_name }}
  {{- end }}
```

## References
- [ElasticSearch Transport](Transport settings | Elastic Cloud on Kubernetes [2.14] | Elastic
  www.elastic.co)
- [ElasticSearch Transport settings](https://www.elastic.co/guide/en/cloud-on-k8s/current/k8s-transport-settings.html#k8s-transport-ca)
- [Security settings](https://www.elastic.co/guide/en/cloud-on-k8s/current/k8s-es-secure-settings.html)
- [Helm chart](https://www.elastic.co/guide/en/cloud-on-k8s/current/k8s-stack-helm-chart.html)
- [K8s service](https://www.elastic.co/guide/en/cloud-on-k8s/current/k8s-services.html)
- [Traffic routing](https://www.elastic.co/guide/en/cloud-on-k8s/current/k8s-traffic-splitting.html)
- [Certificate](https://www.elastic.co/guide/en/cloud-on-k8s/current/k8s-tls-certificates.html)
- [SAML authentication](https://www.elastic.co/guide/en/cloud-on-k8s/current/k8s-saml-authentication.html)
- [Cloudflare](https://blog.palark.com/using-ssl-certificates-from-lets-encrypt-in-your-kubernetes-ingress-via-cert-manager/)
