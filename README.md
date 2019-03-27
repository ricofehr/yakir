# k8s

A base k8s install with Vagrant (Bento/Ubuntu boxes)
- 1 Master (4 Go RAM)
- 2 Nodes (4 Go RAM)
- Network: Weave
- Addons: Heapster, Influxdb, Dashboard

## The cluster

The k8s cluster installed by Ansible
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
