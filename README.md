# yakir

A base k8s install on modern Ubuntu release.

Can be deployed on local with Vagrant (Bento/Ubuntu boxes)
- 3 sizings
  - small: 1 Master and 1 Node (fit to 8Go RAM Laptop with 2 cpu cores)
  - medium : 3 Master and 2 Nodes (fit to 16Go RAM Laptop with 4 cpu cores)
  - large : 3 Master and 5 Nodes (fit to 32Go RAM Laptop with 6 cpu cores)

## Run

```
$ git submodule update --init
$ up
```

Once setup done
- Dashboard is reached here
http://192.168.58.10:8001/api/v1/namespaces/kube-dashboard/services/https:dashboard-kubernetes-dashboard:https/proxy

## Options

```
Usage: ./up [options]
-h           this is some help text.
-d           destroy all previously provisioned vms
-c xxxx      CNI plugin, choices are weave, flannel, calico (default), cilium
-p xxxx      vagrant provider, default is virtualbox
-kp xxxx     keepalived password, default is randomly generated
-m xxxx      container private mirror registry
-s xxxx      sizing deployment, default is small
              - small : 1 manager and 1 nodes, host with 8Go ram / 2 cores
              - medium : 3 managers and 2 nodes host with 16Go ram / 4 cores
              - large : 3 managers and 5 nodes, host with 24Go ram / 6 cores
```

## Releases scope

Deployment of Kubernetes with crio as container engine, and multiple CNI choices
- Kubernetes v1.27.2
- Crio v1.27
- Calico v3.25.1
- Weave v2.8.1
- Flannel v0.22.0
- Cilium v1.13.2
- Gatekeeper v3.12.0

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
Default values are defined following openstack deployment with the repo https://github.com/ricofehr/os-ansible-poc

Once installed, the terraform folder is into tf/openstack, for example destroy the k8s deployment
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
