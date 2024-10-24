## ECK a.k.a ElasticSearch Cloud on Kubernetes

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

## HA

- Elastics Search implementation

  - Multiple nodes
  - Multiple node roles

- K8s implementation
  - dynamic bindings (PVCs)
  - PDB
  - CA and HPA
  - NodeAffinity and topologySpreadConstraints (For topologySpreadConstraints, please make sure eck operator has value `exposedNodeLabels: [ "topology.kubernetes.io/.*", "failure-domain.beta.kubernetes.io/.*" ]`). [References](https://www.elastic.co/guide/en/cloud-on-k8s/current/k8s-advanced-node-scheduling.html)

## Durability
  - Automated snapshot by GKE workload identity instead of secure GCP service account mounted to es node. [References](https://www.elastic.co/guide/en/cloud-on-k8s/current/k8s-snapshots.html)


### Security

- TLS between Node Transport by cert-manager and trust-manager
- TLS from browser to Kibana
