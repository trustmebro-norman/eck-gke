## Install Terragrunt in CloudShell

## Backend generation

## Project structure walkthrough
```
./
├── backend.tf
├── dev
│   ├── inputs.tf
│   ├── main.tf
│   ├── outputs.tf
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
│   ├── es-values.yaml.tftpl
│   ├── externaldns-values.yaml.tftpl
│   ├── kibana-values.yaml.tftpl
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
├── Prerequisites.md
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
│   └── prod.tfvars
└── versions.tf
```
- Consider Terragrunt setup
    - root Terragrunt file `terragrunt.hcl` controls `dev/terragrunt.hcl` and `prod/terragrunt.hcl`
    - root `terragrunt.hcl` is responsible for remote backend and provider config
    - The `<env>/terragrunt.hcl` is reponsible for inheriting config from root, copy all `.tftpl` files which are templates for Helm values and takes `tfvars/common.tfvars` and `tfvars/<env>.tfvars` to pass through Terraform commands

- Consider Terraform modules:
    - We create only one module `modules/eck-gke` as single entrypoint for terragrunt setup
    - Terragrunt will copy `modules/eck-gke` into the `<env>/.terragrunt-cache`. Eg: If you are running terragrunt apply in `prod` so exec path should should be `prod/.terragrunt-cache/**/**`

- Consider Helm chart:
    - Inside `helms` directory, we have bunch of `.yaml.tftpl` files which should be copied in Terragrunt execution time and refered from Terraform resource `helm_release` in `modules/eck-gke/helm.tf`
    - We have local chart `helms/elastic-cluster` where all elastic cluster components (elasticsearch, kibana) generated from
    
