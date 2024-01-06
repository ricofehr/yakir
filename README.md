[![Linter Status](https://github.com/ricofehr/yakir/workflows/Linter/badge.svg)](https://github.com/ricofehr/yakir/actions?workflow=Linter)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](https://raw.githubusercontent.com/ricofehr/yakir/main/LICENSE)

# Yakir - Yet Another Kubernetes Installation Repository

A base k8s install on Ubuntu distribution (Tested on Jammy).

Can be deployed on local with Vagrant (Bento/Ubuntu boxes)
- 3 different sizings
  - small: 1 Managers and 1 Worker (for a Vagrant deployment, fit to 8Go RAM Laptop with 2 cpu cores)
  - medium : 3 Managers and 3 Workers (for a Vagrant deployment, fit to 16Go RAM Laptop with 4 cpu cores)
  - large : 3 Managers and 5 Workers (for a Vagrant deployment, fit to 32Go RAM Laptop with 6 cpu cores)

Can be deployed on KVM hypervisor with Terraform
- Need a dhcp serveur configured with 8 VMs MAC/IP associations : 3 managers and 5 nodes
- Use of 36 vcpus (fit to ~10 real cpu cores), 64Go RAM, and 1To of disk

## Repository structure

```
yakir/
+--ansible/                 Root folder for ansible IaC deployment stack
    +---group_vars/         An Higher variables scope, which overrides defaults/main.yml roles definition
        +---all/
            +---global      Includes all global and transversal variables of the deployment
    +---sizing_vars/        Variables about deployment scope on VMs list - depending about small, medium, larger targeted form factor
    +---collections/        Folder where collections are downloaded from ansible-galaxy command
    +---inventories/        Inventory files, scoped about small, medium, larger targeted form factor
    +---roles/              Ansible roles folder
        +---backup          Deploy velero chart helm, install velero cli command on manager1, and configure a daily backup which post on external S3 bucket 
        +---base            Prerequisites for the Linux OS : global attributes (locale, hostname, time, swap usage, ...), user management, system packages
        +---cert_manager    Deploy certificate-manager helm chart and define Issuers for both letsencrypt and autosigned type
        +---cni             Manage network plugins for Kubernetes : Weave, Flannel, Cilium, Calico
        +---crio            Manage container engine installation
        +---csi             Manage storage plugins for Kubernetes : Rook or Cinder
        +---haproxy         Install and configure haproxy on each manager nodes : expose https (port 443) of the cluster and route traffic to ingress controller
        +---helm            Install helm command and add global helm repositories
        +---ingress         Deploy nginx ingress component on Kubernetes
        +---internal_repos  Configure internal repositories on vms for pypi and apt mirroring requirements 
        +---k8s             Install and configure a Kubernetes deployment with Kubeadm
        +---keepalived      Install keepalived service on manager hosts for a no cloud deployment : ensure a failover IP for control-plane endpoint
        +---kubernetes      External dependencies from a galaxy role (gantsign repository) : install kubernetes binary packages on VMs
        +---kubedashboard   Install and secure Dashboard deployment for Kubernetes
        +---linux_hardening Apply hardening rules for linux kernel, pam logins, and ssh 
        +---logcollect      Deploy fluentbit, elastic, and kibana helm chart, and configure fluentbit for kubernetes logs
        +---monitoring      Deploy prometheus and grafana helm charts, and import grafana dashboard for kubernetes metrics
        +---opa             Install Gatekeeper and define some open policy rules
        +---postinstall     Some validations and post-config topics after Kubernetes deployment
    +---inventory           File created (symlink to targeted file on inventories folder) by the deployment script : used by ansible-playbook to scope the infra
    +---sizing_vars.yml     File created (symlink to targeted file on sizing_vars folder) by the deployment script : used by ansible-playbook to scope the infra metadata
    +---requirements.yml    Collections dependencies, to install in collections folder (ansible-galaxy command is executed by deployment scripts on the root folder)
+--tf/                      Terraform folder which contains HCL provisioning tasks
    +---libvirt/            HCL instructions for provisioning VMs and resources on KVM as prerequisites for k8s installation
+--vagrantfiles/            Deployment flavors vagrantfile for small, medium, large scopes
deploy-to-libvirt           Script for installation on a lived KVM with Terraform (See options below on this page)
up                          Script for local installation with Vagrant (See options below on this page) 
Vagrantfile                 File created (symlink to targeted file on vagrantfiles folder) by the deployment script : used by Vagrant to scope the VMs provisioning
```

## Components

Deployment of Kubernetes with crio as container engine, and multiple CNI choices
- Kubernetes v1.28.1
- Crio v1.27
- Calico v3.25.1
- Weave v2.8.1
- Flannel v0.22.0
- Cilium v1.13.4
- Gatekeeper v3.12.0
- Rook v1.11.9
- Cert Manager v1.12.0
- Ingress Controller v1.4.0
- Fluentbit v2.1.8
- Elastic v8.5.1
- Prometheus v2.46.0
- Grafana v10.0.3
- Velero v1.12.2

## Vagrant deployment

3 providers are defined in Vagrantfiles (using bento boxes)
- virtualbox / libvirt : targeted for x86 systems (amd64 Ubuntu vagrant box)
- parallels : targeted for apple silicon systems (arm64 Ubuntu vagrant box)

### Run

```bash
git submodule update --init
./up
```

Once setup done, get ui endpoints and secrets for ui credentials
```bash
kubectl get ingress -A
kubectl get secrets -A
```


### Options

```
Usage: ./up [options]
-h                                this is some help text.
-d                                destroy all previously provisioned vms
-c xxxx                           CNI plugin, choices are weave, flannel, calico (default), cilium
-p xxxx                           vagrant provider, default is virtualbox
-s xxxx                           sizing deployment, default is small
                                  - small : 1 manager and 1 nodes, host with 8Go ram / 2 cores
                                  - medium : 3 managers and 2 nodes host with 16Go ram / 4 cores
                                  - large : 3 managers and 5 nodes, host with 24Go ram / 6 cores
-t xxxx                           ansible tag, default is none
--keepalived-password xxxx        keepalived password, default is randomly generated
--kube-domain xxxx                global kubernetes domain, default is k8s.local
--container-registry-mirror xxxx  container private mirror registry
--apt-repository-mirror xxxx      mirror repository URL for apt packages
--pypi-repository-mirror xxxx     mirror repository URL for pypi packages
--cert-issuer-type xxxx           Issuer for managing SSL certs, choices are my-ca-issuer (default), letsencrypt-staging, letsencrypt-prod
--backup-server xxxx              External S3 Server (MinIO / AWS S3) URL
--backup-access-key xxxx          S3 Access Key Id
--backup-access-secret xxxx       S3 Access Key Secret
--backup-region xxxx              S3 Bucket Region, default is minio
```

For example, an install on apple silicon with local repository, custom domain, flannel CNI, and medium sizing
```bash
./up -d -c flannel \
  -p parallels \
  -s medium \
  --keepalived-password UdTelzAu \
  --kube-domain k8s.mydomain.io \
  --container-registry-mirror registry.mydomain.io \
  --apt-repository-mirror https://nexus.mydomain.io/repository/jammy \
  --pypi-repository-mirror https://nexus.mydomain.io/repository/pypi-all
```

## Kvm deployment

At first, copy the terraform default vars file, so we can change it to match our infra and network
```bash
cp tf/libvirt/terraform.tfvars.dist tf/libvirt/terraform.tfvars
```

Form factor is fixed at 8 nodes (3 managers, and 5 workers), but could be changed easily with edit this files
- deploy-to-libvirt : changes vms ips and count
- tf/libvirt/terraform.tfvars : changes vms list

Without change (keeping the terraform.tfvars.dist content), the deployment needs following resources
- 8 VMs : 3 managers and 5 workers
- use of 36 vcpus (fit to ~10 real cpu cores), 64Go RAM, and 1To of disk

Edit tf/libvirt/terraform.tfvars file before deployment
- Adapt CPU / RAM / DISK
- Change yakir_domain variable to match your network domain
- Change naming or MAC addresses to match your convention and guidelines


Need some prerequisites
- A libvirt and kvm installation on Linux System
- A linux bridge on the KVM Host system, for example folowing an netplan configuration
```
network:
  version: 2
  renderer: networkd

  ethernets:
    eno1:
      dhcp4: false
      dhcp6: false

  bridges:
    bridge:
      interfaces: [eno1]
      parameters:
        stp: true
        forward-delay: 4
      dhcp4: true
      dhcp6: false
```
- A DHCP server with following lease list : adapt it if changing default MAC addresses and/or IPs

| VM HostName | MAC Address | IP Address |
|-------------|-------------|------------|
| k8s-man-01 | 42:34:00:e2:a1:11 | 192.168.2.210 |
| k8s-man-02 | 42:34:00:a6:d5:21 | 192.168.2.211 |
| k8s-man-03 | 42:34:00:4c:95:a1 | 192.168.2.212 |
| k8s-wrk-01 | 42:34:00:84:5f:13 | 192.168.2.220 |
| k8s-wrk-02 | 42:34:00:28:2d:2c | 192.168.2.221 |
| k8s-wrk-03 | 42:34:00:31:97:53 | 192.168.2.222 |
| k8s-wrk-04 | 42:34:00:04:3e:1d | 192.168.2.223 |
| k8s-wrk-05 | 42:34:00:ba:48:c2 | 192.168.2.224 |

- For use with public exposed IP
  - defined a wildcard *.K8S_DOMAIN which is binding to the public IP
  - add a nat PREROUTING rule to forward incoming public IP on port 80 and 443 connection to the private VIP IP (default is 192.168.2.250)
  - allow port 443 and 80 on Firewall
  - set the issuer for certificate-manager on "letsencrypt-prod"

Use 'deploy-to-libvirt' script for launch deployment
```
Usage: ./deploy-to-libvirt [options]
-h                                this is some help text.
-c xxx                            CNI plugin, choices are cilium / weave / flannel, default is flannel
--failover-ip xxxx                failover ip for managers nodes, default is 192.168.2.250
--ansible-path xxxx               override ansible path
--keepalived-password xxxx        keepalived password, default is randomly generated
--kube-domain xxxx                global kubernetes domain, default is kubernetes.local
--container-registry-mirror xxxx  container private mirror registry
--apt-repository-mirror xxxx      mirror repository URL for apt packages
--pypi-repository-mirror xxxx     mirror repository URL for pypi packages
--cert-issuer-type xxxx           Issuer for managing SSL certs, choices are my-ca-issuer (default), letsencrypt-staging, letsencrypt-prod
--ssh-key-pub xxxx                public rsa key path, default is ~/.ssh/id_rsa.pub
--backup-server xxxx              External S3 Server (MinIO / AWS S3) URL
--backup-access-key xxxx          S3 Access Key Id
--backup-access-secret xxxx       S3 Access Key Secret
--backup-region xxxx              S3 Bucket Region, default is minio
```

Example
```bash
./deploy-to-libvirt -c flannel \
      --cert-issuer-type letsencrypt-prod \
      --container-registry-mirror registry.mydomain.io \
      --apt-repository-mirror https://nexus.mydomain.io/repository/jammy \
      --pypi-repository-mirror https://nexus.mydomain.io/repository/pypi-all \
      --kube-domain k8s.mydomain.io
```

## Backup

Prerequisites
- have a S3 instance reachable (MinIO or AWS S3)
- generate access key credentials (ID and Secret) with the S3 instance
- create a bucket named "velero"
- provide server URL, credentials, and region (for MinIO, you can create a "minio" region) on up / deploy-to-libvirt commands (See parameters below on README)

Add parameters to enable a daily backup with Velero, for example (same backup parameters are availabe with deploy-to-libvirt command)
```bash
./up -s large \
  -c cilium \
  --kube-domain k8s.local \
  -p libvirt \
  --backup-server https://minio.local \
  --backup-access-key xxxxxxxxxxxxx \
  --backup-access-secret xxxxxxxxxxxxxxxxxxxxx \
  --backup-region minio
```

## TODO

- Secure k8s settings with CIS benchmark recommandations
- Work on opentelemetry integration
- Add Gitops tools

