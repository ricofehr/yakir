# k8s

A base k8s install with Vagrant (Bento/Ubuntu boxes)
- 1 Master (4 Go RAM)
- 2 Nodes (4 Go RAM)
- Network: Weave
- Addons: Heapster, Influxdb, Dashboard

## The cluster

The k8s cluster installed by Ansible on Local with Vagrant
![k8s cluster](https://github.com/ricofehr/k8s/raw/master/k8s-cluster.png)

## Requirements

Resources
- 12 Go RAM
- 4 cpu cores

Prerequisites
- Ansible for provision

## Run

```
$ git submodule update --init
$ vagrant up
```

Once setup done
- Dashboard is reached here
http://192.168.78.10:8001/api/v1/namespaces/kube-system/services/https:dashboard-kubernetes-dashboard:https/proxy/

## Openstack deployment

An openstack deployment is setted with Terraform, use 'deployos' script for managed this
```
Usage: ./deployos [options]
-h           this is some help text.
-a xxxx      openstack auth url, default is http://172.29.236.101:5000/v3
-u xxxx      openstack user, default is tenant0
-p xxxx      openstack password, default is tenant0
-t xxxx      openstack tenant, default is tenant0
-r xxxx      openstack region, default is RegionOne
-fm xxxx     openstack flavor for master instance, default is large
-fn xxxx     openstack flavor for nodes instance, default is xlarge
-s xxxx      openstack tenant security group, default is k8s
-o xxxx      openstack operating system image, default is bionic
-k xxxx      public rsa key path, default is ~/.ssh/id_rsa.pub
```
Default values are defined following openstack deployment with the repo https://github.com/ricofehr/os-ansible-poc

Once installed, the terraform folder is into tf/openstack, for example destroy the k8s deployment
```
cd tf/openstack && terraform destroy
```
