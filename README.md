[![Linter Status](https://github.com/ricofehr/yakir/workflows/Linter/badge.svg)](https://github.com/ricofehr/yakir/actions?workflow=Linter)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](https://raw.githubusercontent.com/ricofehr/yakir/main/LICENSE)

# yakir

A base k8s install on Ubuntu release (Tested on Jammy).

Can be deployed on local with Vagrant (Bento/Ubuntu boxes) or on Openstack (same VMs count, but using Openstack defined flavors for cpu/ram/disk definition) 
- 3 different sizings
  - small: 1 Master and 1 Node (for a Vagrant deployment, fit to 8Go RAM Laptop with 2 cpu cores)
  - medium : 3 Master and 2 Nodes (for a Vagrant deployment, fit to 16Go RAM Laptop with 4 cpu cores)
  - large : 3 Master and 5 Nodes (for a Vagrant deployment, fit to 32Go RAM Laptop with 6 cpu cores)

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
        +---cert            Manage self-signed certificate creation (used for wildcard ingress FQDN)
        +---cni             Manage network plugins for Kubernetes
        +---crio            Manage container engine installation
        +---helm            Install helm command and add global helm repositories
        +---ingress         Deploy nginx ingress component on Kubernetes
        +---k8s             Install and configure a Kubernetes deployment with Kubeadm
        +---keepalived      Install keepalived service on manager hosts for a no cloud deployment : ensure a failover IP for control-plane endpoint
        +---kubernetes      External dependencies from a galaxy role (gantsign repository) : install kubernetes binary packages on VMs
        +---kubedashboard   Install and secure Dashboard deployment for Kubernetes
        +---opa             Install Gatekeeper and define some open policy rules
        +---postinstall     Some validations and post-config topics after Kubernetes deployment
    +---inventory           File created (symlink to targeted file on inventories folder) by the deployment script : used by ansible-playbook to scope the infra
    +---sizing_vars.yml     File created (symlink to targeted file on sizing_vars folder) by the deployment script : used by ansible-playbook to scope the infra metadata
    +---requirements.yml    Collections dependencies, to install in collections folder (ansible-galaxy command is executed by deployment scripts on the root folder)
+--tf/                      Terraform folder which contains HCL provisioning tasks
    +---openstack/          HCL instructions for provisioning VMs and resources on Openstack as prerequisites for k8s installation
+--vagrantfiles/            Deployment flavors vagrantfile for small, medium, large scopes
deploy-to-openstack         Script for installation on a lived openstack with Terraform (See options below on this page)
up                          Script for local installation with Vagrant (See options below on this page) 
Vagrantfile                 File created (symlink to targeted file on vagrantfiles folder) by the deployment script : used by Vagrant to scope the VMs provisioning
```

## Components

Deployment of Kubernetes with crio as container engine, and multiple CNI choices
- Kubernetes v1.27.2
- Crio v1.27
- Calico v3.25.1
- Weave v2.8.1
- Flannel v0.22.0
- Cilium v1.13.2
- Gatekeeper v3.12.0

## Vagrant deployment

2 providers are defined in Vagrantfiles (using bento boxes)
- virtualbox : targeted for x86 systems (amd64 Ubuntu vagrant box)
- parallels : targeted for apple silicon systems (arm64 Ubuntu vagrant box)

### Run

```
$ git submodule update --init
$ up
```

Once setup done
- Dashboard is reached here
http://192.168.58.10:8001/api/v1/namespaces/kube-dashboard/services/https:dashboard-kubernetes-dashboard:https/proxy

### Options

```
Usage: ./up [options]
-h           this is some help text.
-d           destroy all previously provisioned vms
-c xxxx      CNI plugin, choices are weave, flannel, calico (default), cilium
-p xxxx      vagrant provider, choices are virtualbox (default) or parallels
-kp xxxx     keepalived password, default is randomly generated
-m xxxx      container private mirror registry (default is none : get container images directly from Internet)
-s xxxx      sizing deployment, default is small
              - small : 1 manager and 1 nodes, host with 8Go ram / 2 cores
              - medium : 3 managers and 2 nodes host with 16Go ram / 4 cores
              - large : 3 managers and 5 nodes, host with 24Go ram / 6 cores
```

## Openstack deployment

An openstack deployment is setted with Terraform, use 'deployos' script for managed this
```
Usage: ./deploy-to-openstack [options]
-h           this is some help text.
-a xxxx      openstack auth url, default is http://172.29.236.101:5000/v3
-u xxxx      openstack user, default is tenant0
-p xxxx      openstack password, default is tenant0
-t xxxx      openstack tenant, default is tenant0
-r xxxx      openstack region, default is RegionOne
-s xxxx      deployment sizing, choices are small / medium / large, default is small
-fm xxxx     openstack flavor for master instance, default is large
-fn xxxx     openstack flavor for nodes instance, default is xlarge
-fip xxxx    openstack floatingip network id, no default
-oscrt xxxx  openstack ssl certificate path
-secgrp xxxx openstack tenant security group, default is k8s
-snet xxxx   openstack subnet id, no default
-m xxxx      mirror registry for docker.io images
-o xxxx      openstack operating system image, default is bionic
-k xxxx      public rsa key path, default is ~/.ssh/id_rsa.pub
-w xxxx	     override ansible path
```

Tested with an openstack deployment from the repo https://github.com/ricofehr/os-ansible-poc

Once installed, the terraform state file is into tf/openstack, for example destroy the k8s deployment
```
cd tf/openstack && terraform destroy
```

## TODO

- Add monitoring stack (prometheus, grafana)
- Add logging collector stack (fluentbit)
- Add backup process (backup etcd and storage repositories)
- Add hardening stuff on Linux OS, and k8s settings
- Add csi for a distributed Filesystem like Ceph
- Work on a kvm deployment
- Work on opentelemetry integration
