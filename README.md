[![Linter Status](https://github.com/ricofehr/yakir/workflows/Linter/badge.svg)](https://github.com/ricofehr/yakir/actions?workflow=Linter)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](https://raw.githubusercontent.com/ricofehr/yakir/main/LICENSE)

# Yakir - Yet Another Kubernetes Installation Repository

A base k8s install on Ubuntu distribution (Tested on Noble).

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
        +---bench           Launch, display, and save a kube-bench analysis
        +---cert_manager    Deploy certificate-manager helm chart and define Issuers for both letsencrypt and autosigned type
        +---cni             Manage network plugins for Kubernetes : Flannel, Cilium, Calico
        +---crio            Manage container engine installation
        +---csi             Manage storage plugins for Kubernetes : Rook or Cinder
        +---gitops          Deploy Argo CD and the CloudNativePG operator, and register the ai-factory root application (skipped unless --gitops-repo is set)
        +---haproxy         Install and configure haproxy on each manager nodes : expose https (port 443) of the cluster and route traffic to ingress controller
        +---helm            Install helm command and add global helm repositories
        +---ingress         Deploy nginx ingress component on Kubernetes
        +---internal_repos  Configure internal repositories on vms for pypi and apt mirroring requirements
        +---k8s             Install and configure a Kubernetes deployment with Kubeadm
        +---keepalived      Install keepalived service on manager hosts for a no cloud deployment : ensure a failover IP for control-plane endpoint
        +---linux_hardening Apply hardening rules for linux kernel, pam logins, and ssh
        +---logcollect      Deploy loki and fluentbit helm charts, and configure fluentbit to ship kubernetes logs to loki (browsed from the grafana deployed by the monitoring role)
        +---monitoring      Deploy prometheus and grafana helm charts, and import grafana dashboard for kubernetes metrics
        +---opa             Install Gatekeeper and define some open policy rules
        +---postinstall     Some validations and post-config topics after Kubernetes deployment
        +---reflector       Deploy emberstack reflector, which mirrors an annotated configmap or secret into the other namespaces that need it
        +---reloader        Deploy stakater reloader, which rolls the annotated workloads when a configmap or a secret they reference changes
    +---inventory           File created (symlink to targeted file on inventories folder) by the deployment script : used by ansible-playbook to scope the infra
    +---sizing_vars.yml     File created (symlink to targeted file on sizing_vars folder) by the deployment script : used by ansible-playbook to scope the infra metadata
    +---requirements.yml    Collections dependencies, to install in collections folder (ansible-galaxy command is executed by deployment scripts on the root folder)
+--tf/                      Terraform folder which contains HCL provisioning tasks
    +---libvirt/            HCL instructions for provisioning VMs and resources on KVM as prerequisites for k8s installation
+--vagrantfiles/            Deployment flavors vagrantfile for small, medium, large scopes
deploy-to-libvirt           Script for installation on a lived KVM with Terraform (See options below on this page)
requirements.txt            Python requirements for ansible installation
up                          Script for local installation with Vagrant (See options below on this page)
Vagrantfile                 File created (symlink to targeted file on vagrantfiles folder) by the deployment script : used by Vagrant to scope the VMs provisioning
```

## Components

| Name | Version | Description |
|------|---------|-------------|
| Kubernetes | v1.35.2 | Container Orchestrator |
| Crio | v1.35 | Container Runtime |
| Cilium | v1.19.1 | CNI Plugin (set this one with "-c cilium") |
| Calico | v3.31.4 | CNI Plugin (set this one with "-c calico") |
| Flannel | v0.28.1 | CNI Plugin (set this one with "-c flannel") |
| Getekeeper | v3.21.1 | Apply OpenPolicyAgent rules |
| Rook | v1.19.2 | Distributed Storage with Ceph, CSI plugin for the Kubernetes installation |
| Ceph | v20.2.0 | Distributed Storage |
| Cert Manager | v1.19.4 | Generate SSL certs for ingress object with auto-signed CA or lets-encrypt (set with bash parameter) |
| Ingress Controller | v3.6.7 | Traefik Ingress Controller |
| Fluentbit | v4.2.3 | Cluster Log collector service |
| Loki | v3.6.11 | Cluster Log storage, queried from Grafana (no dedicated UI) |
| Prometheus | v3.10.0 | Cluster Monitoring metrics storage |
| Grafana | v12.3.1 | Cluster Monitoring metrics visualization |
| Velero | v1.18.0 | Cluster Backup service, set a complete daily backup on external S3 service |
| Kube-bench | v0.15.0 | Install kube-bench on first manager node, and launch analysis (with result output) on each playbook execution |
| Reloader | v1.4.22 | Restart the annotated workloads when a ConfigMap or a Secret they reference changes |
| Reflector | v10.0.65 | Mirror an annotated ConfigMap or Secret into other namespaces, and keep the copies in step |
| Argo CD | v3.5.3 | GitOps controller reconciling the ai-factory applications (deployed only with --gitops-repo) |
| CloudNativePG | v1.30.0 | PostgreSQL operator backing the ai-factory applications (deployed only with --gitops-repo) |

## Vagrant deployment

3 providers are defined in Vagrantfiles (using bento boxes)
- virtualbox / libvirt : targeted for x86 systems (amd64 Ubuntu vagrant box)
- parallels : targeted for apple silicon systems (arm64 Ubuntu vagrant box)

## Ansible install

Runned during up and deploy-to-libvirt scripts
```bash
python3 -mvenv venv
source venv/bin/activate
pip3 install -r requirements.txt
```

### Run

```bash
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
--gitops-repo xxxx                ai-factory git repository url; enables the gitops role when set
--gitops-branch xxxx              ai-factory git branch, default is main
--gitops-ssh-key xxxx             private deploy key for the ai-factory repository
--llama-api-key xxxx              api key of the llama-server backing the LLM gateway
--github-token xxxx               GitHub personal access token for the MCP gateway and context graph
--github-app-id xxxx              GitHub App id used by the self-hosted runners
--github-app-installation-id xxxx GitHub App installation id used by the self-hosted runners
--github-app-key xxxx             GitHub App private key (.pem) path
```

For example, an install on apple silicon with local repository, custom domain, flannel CNI, and medium sizing
```bash
./up -d -c flannel \
  -p parallels \
  -s medium \
  --keepalived-password UdTelzAu \
  --kube-domain k8s.mydomain.io \
  --container-registry-mirror registry.mydomain.io \
  --apt-repository-mirror https://nexus.mydomain.io/repository/noble \
  --pypi-repository-mirror https://nexus.mydomain.io/repository/pypi-all
```

## Kvm deployment (amd64 arch only)

At first, copy the terraform default vars file, so we can change it to match our infra and network
```bash
cp tf/libvirt/terraform.tfvars.dist tf/libvirt/terraform.tfvars
```

Worker root disks hold every container image the cluster pulls. The base install alone
caches ~8Go per worker, so the default was raised from 15Go to 40Go — at 15Go the nodes hit
`DiskPressure` and start evicting pods with "no space left on device" as soon as anything
substantial is deployed on top. The disks are thin-provisioned, so the larger size costs
nothing until it is used.

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
| k8s-man-01 | 42:34:00:e2:a1:11 | 192.168.3.210 |
| k8s-man-02 | 42:34:00:a6:d5:21 | 192.168.3.211 |
| k8s-man-03 | 42:34:00:4c:95:a1 | 192.168.3.212 |
| k8s-wrk-01 | 42:34:00:84:5f:13 | 192.168.3.220 |
| k8s-wrk-02 | 42:34:00:28:2d:2c | 192.168.3.221 |
| k8s-wrk-03 | 42:34:00:31:97:53 | 192.168.3.222 |
| k8s-wrk-04 | 42:34:00:04:3e:1d | 192.168.3.223 |
| k8s-wrk-05 | 42:34:00:ba:48:c2 | 192.168.3.224 |

- For use with public exposed IP
  - defined a wildcard *.K8S_DOMAIN which is binding to the public IP
  - add a nat PREROUTING rule to forward incoming public IP on port 80 and 443 connection to the private VIP IP (default is 192.168.3.250)
  - allow port 443 and 80 on Firewall
  - set the issuer for certificate-manager on "letsencrypt-prod"

- The deployment reboots each VM once, early on, to apply the `net.ifnames=0`
  kernel command line set by the `linux_hardening` role. Interfaces come back as
  `eth*`, which is what `keepalived_eth` and the control-plane VIP are bound to.
  The reboot is skipped on hosts already running that command line, so re-running
  the deployment against a live cluster does not restart it.

Use 'deploy-to-libvirt' script for launch deployment
```
Usage: ./deploy-to-libvirt [options]
-h                                this is some help text.
-c xxx                            CNI plugin, choices are cilium / calico / weave / flannel, default is flannel
--failover-ip xxxx                failover ip for managers nodes, default is 192.168.3.250
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
--gitops-repo xxxx                ai-factory git repository url; enables the gitops role when set
--gitops-branch xxxx              ai-factory git branch, default is main
--gitops-ssh-key xxxx             private deploy key for the ai-factory repository
--llama-api-key xxxx              api key of the llama-server backing the LLM gateway
--github-token xxxx               GitHub personal access token for the MCP gateway and context graph
--github-app-id xxxx              GitHub App id used by the self-hosted runners
--github-app-installation-id xxxx GitHub App installation id used by the self-hosted runners
--github-app-key xxxx             GitHub App private key (.pem) path
```

Example
```bash
./deploy-to-libvirt -c flannel \
      --cert-issuer-type letsencrypt-prod \
      --container-registry-mirror registry.mydomain.io \
      --apt-repository-mirror https://nexus.mydomain.io/repository/noble \
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

## Reloader

A ConfigMap or Secret change does not restart the workloads reading it: a mounted
volume is refreshed eventually, but a value consumed through `env` or `envFrom`
keeps whatever the container read at startup. The reloader role deploys
[stakater/reloader](https://github.com/stakater/reloader) in the `kube-reloader`
namespace, which watches every namespace and rolls the workloads that opt in.

Opt a Deployment, StatefulSet or DaemonSet in with an annotation on the workload
itself (not on its pod template)

```yaml
metadata:
  annotations:
    # roll on a change of any configmap or secret the workload references
    reloader.stakater.com/auto: "true"
    # or scope it to named resources instead
    configmap.reloader.stakater.com/reload: "my-configmap,my-other-configmap"
    secret.reloader.stakater.com/reload: "my-secret"
```

Nothing is reloaded without one of those annotations. To reload every workload of
the cluster instead, including the platform stack, run with
`-e reloader_auto_reload_all=true`; a workload then opts out with
`reloader.stakater.com/auto: "false"`.

The annotation gates what is *restarted*, not what is *read*: watching the whole
cluster means the chart binds a ClusterRole granting the reloader service account
`get`/`list`/`watch` on every ConfigMap and Secret of the cluster, the velero,
rook-ceph and Argo CD credentials included. That is the cost of a cluster-wide
watcher - to narrow it, set `reloader.watchGlobally: false` and list the
namespaces to watch in `reloader.namespaces`, which makes the chart create a
namespace scoped Role in each one instead of the ClusterRole.

Argo CD managed workloads are worth a thought: the default reload strategy stamps
an annotation on the pod template, which Argo CD then sees as drift and self-heals
away, so an opted-in workload rolls twice. Set `reloader.reloadStrategy: env-vars`
for those if the double rollout matters.

## Reflector

A `secretKeyRef` only resolves inside its own namespace, so a value several
namespaces need has to exist several times - the gitops role still writes the
LiteLLM master key into two namespaces by hand for exactly that reason, and
migrating it is a later change. The reflector role deploys
[emberstack/kubernetes-reflector](https://github.com/emberstack/kubernetes-reflector)
in the `kube-reflector` namespace, which mirrors an annotated resource into the
namespaces that need it and keeps the copies in step with the source.

Nothing is copied anywhere until the **source** opts in. Annotate the source
secret or configmap, and let reflector create the mirrors

```yaml
metadata:
  annotations:
    reflector.v1.k8s.emberstack.com/reflection-allowed: "true"
    # which namespaces may hold a mirror. Comma separated regexes, each matched
    # against the whole namespace name, so these two entries are exact - while
    # "ai-.*" would also cover ai-devpods and ai-runners.
    reflector.v1.k8s.emberstack.com/reflection-allowed-namespaces: "ai-llm,ai-mcp"
    # create the mirrors automatically rather than declaring each one, in these
    # namespaces - which are checked against the allowed list above as well
    reflector.v1.k8s.emberstack.com/reflection-auto-enabled: "true"
    reflector.v1.k8s.emberstack.com/reflection-auto-namespaces: "ai-llm,ai-mcp"
```

Treat both namespace lists as mandatory and keep them narrow. An empty or absent
list means *every* namespace, so an auto-enabled source without them is mirrored
cluster-wide, `kube-system` included. `reflection-allowed-namespaces` is the one
that matters most: it alone gates the manual `reflects` path below, so a secret
whose allowed list is open can be pulled into any namespace by anyone able to
create an empty secret there.

Or declare the mirror yourself, naming its source as `<namespace>/<name>`

```yaml
metadata:
  annotations:
    reflector.v1.k8s.emberstack.com/reflects: "kube-cert/wildcard-tls"
```

A mirror written by something other than reflector - an ansible task, a helm
chart - needs `reflector.v1.k8s.emberstack.com/reflected-version: ""` alongside
it. Reflector stamps the source's version on a mirror it has synced and skips a
mirror that already carries the current one, so re-applying a manifest over a
synced mirror otherwise leaves the re-applied content in place for good.

Two behaviours worth knowing before relying on it: deleting the source deletes
every automatic mirror, as does narrowing the allowed namespaces afterwards.

The third is a trap, and upstream documents the opposite. A pre-existing
resource of the same name is only skipped when reflector reacts to a change of
the *source*. On a namespace event - including the replay of every namespace
each time the watch session restarts, hourly by default - it instead creates,
takes the 409, re-reads the existing object and patches its data, with no check
that the object is a mirror of anything (`ResourceMirror.ResourceReflect`, and
`SecretMirror` replaces `data` wholesale). So an annotated source silently
overwrites any same-named secret or configmap in every namespace its annotations
permit. Name your target namespaces, and never give a source a name that
collides with something you do not own.

Mirroring means writing, so this controller's ClusterRole covers every configmap
and secret of the cluster with every verb - broader than the reloader's read-only
watch, and not something the chart lets you trim.

`reflector_excluded_namespaces` narrows that, but not in the direction the name
suggests: it filters the watch by the namespace a resource *lives in*, so an
excluded namespace can never be a reflection **source**. Nothing stops it being
a **target** - namespaces are cluster scoped, their events are never filtered,
and upstream pins that behaviour in a test. The default of `kube-system`
therefore means no secret sitting in `kube-system` can be fanned out across the
cluster, and equally that `kube-root-ca.crt` and its neighbours cannot be used
as a mirror source. Keeping mirrors *out* of a namespace is the source
annotations' job, above. Unlike those annotations, this value is a glob and not
a regex - `kube-*` works, `kube-.*` silently matches nothing. Set it to `""` for
the chart's own default of excluding nothing.

## GitOps and the AI factory

The cluster stops at "base kubernetes". Everything above it — the AI software factory —
lives in a separate `ai-factory` repository that Argo CD reconciles, so factory changes
ship with a `git push` instead of another playbook run against a live cluster.

The `gitops` role is the seam. It is **skipped entirely** unless `--gitops-repo` is set, so
a plain `./up` or `./deploy-to-libvirt` behaves exactly as before. When it is set the role:

- deploys Argo CD (ingress on `gitops.K8S_DOMAIN`) and the CloudNativePG operator,
- stores the credentials the Argo CD applications cannot generate for themselves,
- registers a root application pointing at the `apps/` folder of the ai-factory repository.

```bash
./deploy-to-libvirt -c cilium \
  --kube-domain k8s.mydomain.io \
  --gitops-repo git@github.com:ricofehr/ai-factory.git \
  --gitops-ssh-key ~/.ssh/ai_factory_deploy \
  --llama-api-key xxxxxxxxxxxx \
  --github-app-id 123456 \
  --github-app-installation-id 7654321 \
  --github-app-key ~/.ssh/arc-github-app.pem
```

Bootstrap secrets are created from these parameters rather than committed to the GitOps
repository, which keeps `ai-factory` free of credentials. The LiteLLM master key is the one
exception: it is generated in-cluster on first run and reused afterwards, so virtual keys
issued against it survive a replay.

Once Argo CD is up, get the initial admin password with

```bash
kubectl -n kube-gitops get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d
```

## TODO

- Secure k8s settings with CIS benchmark recommandations
- Work on opentelemetry integration

