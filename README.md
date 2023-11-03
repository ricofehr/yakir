[![Linter Status](https://github.com/ricofehr/yakir/workflows/Linter/badge.svg)](https://github.com/ricofehr/yakir/actions?workflow=Linter)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](https://raw.githubusercontent.com/ricofehr/yakir/main/LICENSE)

# Yakir - Yet Another Kubernetes Installation Repository

A base k8s install on Ubuntu distribution (Tested on Jammy).

Can be deployed on local with Vagrant (Bento/Ubuntu boxes) or on Openstack 
- 3 different sizings
  - small: 1 Managers and 1 Worker (for a Vagrant deployment, fit to 8Go RAM Laptop with 2 cpu cores)
  - medium : 3 Managers and 3 Workers (for a Vagrant deployment, fit to 16Go RAM Laptop with 4 cpu cores)
  - large : 3 Managers and 5 Workers (for a Vagrant deployment, fit to 32Go RAM Laptop with 6 cpu cores)

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
        +---base            Prerequisites for the Linux OS : global attributes (locale, hostname, time, swap usage, ...), user management, system packages
        +---cert_manager    Deploy certificate-manager helm chart and define Issuers for both letsencrypt and autosigned type
        +---cni             Manage network plugins for Kubernetes : Weave, Flannel, Cilium, Calico
        +---crio            Manage container engine installation
        +---csi             Manage storage plugins for Kubernetes : Rook or Cinder
        +---haproxy         Install and configure haproxy on each manager nodes : expose https (port 443) of the cluster and route traffic to ingress controller
        +---helm            Install helm command and add global helm repositories
        +---ingress         Deploy nginx ingress component on Kubernetes
        +---k8s             Install and configure a Kubernetes deployment with Kubeadm
        +---keepalived      Install keepalived service on manager hosts for a no cloud deployment : ensure a failover IP for control-plane endpoint
        +---kubernetes      External dependencies from a galaxy role (gantsign repository) : install kubernetes binary packages on VMs
        +---kubedashboard   Install and secure Dashboard deployment for Kubernetes
        +---logcollect      Deploy fluentbit, elastic, and kibana helm chart, and configure fluentbit for kubernetes logs
        +---monitoring      Deploy prometheus and grafana helm charts, and import grafana dashboard for kubernetes metrics
        +---opa             Install Gatekeeper and define some open policy rules
        +---postinstall     Some validations and post-config topics after Kubernetes deployment
    +---inventory           File created (symlink to targeted file on inventories folder) by the deployment script : used by ansible-playbook to scope the infra
    +---sizing_vars.yml     File created (symlink to targeted file on sizing_vars folder) by the deployment script : used by ansible-playbook to scope the infra metadata
    +---requirements.yml    Collections dependencies, to install in collections folder (ansible-galaxy command is executed by deployment scripts on the root folder)
+--tf/                      Terraform folder which contains HCL provisioning tasks
    +---openstack/          HCL instructions for provisioning VMs and resources on Openstack as prerequisites for k8s installation
    +---libvirt/            HCL instructions for provisioning VMs and resources on KVM as prerequisites for k8s installation
+--vagrantfiles/            Deployment flavors vagrantfile for small, medium, large scopes
deploy-to-libvirt           Script for installation on a lived KVM with Terraform (See options below on this page)
deploy-to-openstack         Script for installation on a lived openstack with Terraform (See options below on this page)
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

## Vagrant deployment

2 providers are defined in Vagrantfiles (using bento boxes)
- virtualbox : targeted for x86 systems (amd64 Ubuntu vagrant box)
- parallels : targeted for apple silicon systems (arm64 Ubuntu vagrant box)

### Run

```
$ git submodule update --init
$ ./up
```

Once setup done, get ui endpoints
```
$ kubectl get ingress -A
```


### Options

```
Usage: ./up [options]
-h           this is some help text.
-d           destroy all previously provisioned vms
-c xxxx      CNI plugin, choices are weave, flannel, calico (default), cilium
-i xxxx      Issuer for managing SSL certs, choices are my-ca-issuer (default), letsencrypt-staging, letsencrypt-prod
-p xxxx      vagrant provider, default is virtualbox
-kp xxxx     keepalived password, default is randomly generated
-kd xxxx     global kubernetes domain, default is k8s.local
-mr xxxx     container private mirror registry
-ma xxxx     mirror repository URL for apt packages
-mp xxxx     mirror repository URL for pypi packages
-s xxxx      sizing deployment, default is small
              - small : 1 manager and 1 nodes, host with 8Go ram / 2 cores
              - medium : 3 managers and 2 nodes host with 16Go ram / 4 cores
              - large : 3 managers and 5 nodes, host with 24Go ram / 6 cores
```

For example, an install on apple silion with local repository, custom domain, flannel CNI, and medium sizing, letsencrypt prod for certs management
```
$ ./up -d -c flannel -i letsencrypt-prod -p parallels -kp UdTelzAu -kd k8s.mydomain.io -mr registry.mydomain.io -ma https://nexus.mydomain.io/repository/jammy -mp https://nexus.mydomain.io/repository/pypi-all -s medium
```

## Kvm deployment

At first, copy the terraform default vars file, so we can change it to match our infra and network
```
$ cp tf/libvirt/terraform.tfvars.dist tf/libvirt/terraform.tfvars
```

Form factor is fixed at 8 nodes (3 managers, and 5 workers), but could be changed easily with edit this files
- deploy-to-libvirt : changes vms ips and count
- tf/libvirt/terraform.tfvars : changes vms list

Without change (keeping the terraform.tfvars.dist content), the deployment needs following resources
- 8 VMs : 3 managers and 5 workers
- use of 36 vcpus (well count for ~10 real cpu cores), 64Go RAM, and 1To of disk

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
- A DHCP server setted with MAC addresses of VMs as following (if keeping MAC addresses in terraform.tfvars.dist and IPs in deploy-to-libvirt script)
  - k8s-man-01 : "42:34:00:e2:a1:11" -> 192.168.2.210 
  - k8s-man-02 : "42:34:00:a6:d5:21" -> 192.168.2.211
  - k8s-man-03 : "42:34:00:4c:95:a1" -> 192.168.2.212
  - k8s-wrk-01 : "42:34:00:84:5f:13" -> 192.168.2.220
  - k8s-wrk-02 : "42:34:00:28:2d:2c" -> 192.168.2.221
  - k8s-wrk-03 : "42:34:00:31:97:53" -> 192.168.2.222
  - k8s-wrk-04 : "42:34:00:04:3e:1d" -> 192.168.2.223
  - k8s-wrk-95 : "42:34:00:ba:48:c2" -> 192.168.2.224
- For use with public exposed IP
  - defined a wildcard *.K8S_DOMAIN which is binding to the public IP
  - add a nat PREROUTING rule to forward incoming public IP on port 80 and 443 connection to the private VIP IP (default is 192.168.2.250)
  - allow port 443 and 80 on Firewall
  - set the issuer for certificate-manager on "letsencrypt-prod"

Use 'deploy-to-libvirt' script for launch deployment
```
Usage: ./deploy-to-libvirt [options]
-h           this is some help text.
-c xxx       CNI plugin, choices are cilium / weave / flannel, default is flannel
-i xxxx      certificate issuer, choices are my-selfsigned-ca / letsencrypt-staging / letsencrypt-prod, default is my-selfsigned-ca
-k xxxx      public rsa key path, default is ~/.ssh/id_rsa.pub
-kd xxxx     global kubernetes domain, default is kubernetes.local
-mr xxxx     container private mirror registry
-ma xxxx     mirror repository URL for apt packages
-mp xxxx     mirror repository URL for pypi packages
-vip1 xxxx   failover ip for managers nodes, default is 192.168.2.250
-w xxxx	     override ansible path
```

Example
```
./deploy-to-libvirt -n flannel -c letsencrypt-prod -mr registry.mydomain.io -ma https://nexus.mydomain.io/repository/jammy -mp https://nexus.mydomain.io/repository/pypi-all -kd k8s.mydomain.io
```

## Openstack deployment

An openstack deployment is setted with Terraform, use 'deploy-to-openstack' script for managed this
```
Usage: ./deploy-to-openstack [options]
-h           this is some help text.
-a xxxx      openstack auth url, default is http://172.29.236.101:5000/v3
-u xxxx      openstack user, default is tenant0
-p xxxx      openstack password, default is tenant0
-t xxxx      openstack tenant, default is tenant0
-r xxxx      openstack region, default is RegionOne
-s xxxx      deployment sizing, choices are small / medium / large, default is small
-fm xxxx     openstack flavor for manager instance, default is large
-fn xxxx     openstack flavor for nodes instance, default is xlarge
-fip xxxx    openstack floatingip network id, no default
-kd xxxx     global kubernetes domain, default is k8s.local
-vip1 xxxx   failover ip for managers nodes
-oscrt xxxx  openstack ssl certificate path
-secgrp xxxx openstack tenant security group, default is k8s
-net xxxx    openstack net id, no default
-snet xxxx   openstack subnet id, no default
-m xxxx      mirror registry for docker.io, quay.io, registry.k8s.io images
-o xxxx      openstack operating system image, default is jammy
-k xxxx      public rsa key path, default is ~/.ssh/id_rsa.pub
-w xxxx	     override ansible path
```

Tested with an openstack deployment from the repo https://github.com/ricofehr/mos

Once installed, the terraform state file is into tf/openstack, for example destroy the k8s deployment
```
cd tf/openstack && terraform destroy
```

## TODO

- Add backup process (backup etcd and storage repositories)
- Add hardening stuff on Linux OS, and k8s settings
- Work on a native kvm deployment -> WIP
- Work on opentelemetry integration
