# v0.6.2

## Changes by Kind

### New Feature

- For deployment on openstack, install Openstack controller Manager, and Cinder CSI Plugin
- Add private mirror container registry option (default is to use public registries as before)

### Bug or Regression

- Fix a syntax typo on cloud config file

### Inprovement

- Group components version variables in the same ansible file (at group_vars/all/global)

### Other

- Clean unused vars files on Ansible folders


# v0.6.1

## Changes by Kind

### Bug or Regression

- Freeze kubernetes version to v1.27.1
- Fix installation with openstack provider

### Improvement

- Some Ansible syntax improvement and rework


# v0.6

## Changes by Kind

### New Feature

- Add arm64 (apple silicon) boxes on Vagrantfile for parallels provider
- Add Getekeeper with a rule to ensure pod-security enforcing on Namespaces creation

### Bug or Regression

- Fix kubelet installation

### Improvement

- Upgrade Kubernetes version to v1.27.0 (from v1.25)
- Ansible improvement : replace pause tasks with wait-until workflow
- Add some hardening settings on Dashboard deployment

### Other

- Remove CI stack deployment : no more Gitea, Sonar, Jenkinsx, Docker-registry, or Istio chart installation
- Remove Monitoring and Logging stack deployment : no more ELK, Prometheus or Grafana chart installation
- Remove some debug instructions


# v0.6-rc5

## Changes by Kind

### Bug or Regression

- Fix apt package install issue with update of gpg key id
- Fix kubenretes_cni package version


# v0.6-rc4

## Changes by Kind

### Bug or Regression

- Fix cgroupDriver setting to systemd value
- Add csr approvement command after Kubernetes installation to avoid have CSR standing not validated

### Improvement

- Rework kubeadm instructions to load config from file


# v0.6-rc3

## Changes by Kind

### Bug or Regression

- Fix deprecated "warn" attributes on Ansible

### Improvement

- Change small flavor deployment scope


# v0.6-rc2

## Changes by Kind

### Bug or Regression

- Add pause between terraform part and ansible execution during deployment on openstack


# v0.6-rc1

## Changes by Kind

### New Feature

- Replace Docker by Crio v1.24 as container engine
- Update Vagrant box to Jammy (20.04) Ubuntu release
- Add calico and Flannel CNI choices along Weave already present

### Bug or Regression

### Improvement

- Update Kubernetes version from 1.20 to 1.25
- Update Helm to v3.10.0 (from v3.4.2)
- Update Ingress (4.3.0), Gitea (6.0.3), Jenkinsx (4.2.10), Sonar (9.6.0) Dashboard (5.10.0) chart versions
- Use variable for define disk persistence needs on helm deployments
- Use ansible helm collection to deploy helm chart, instead of shell commands

### Other

- Disable ELK and Prometheus / Grafana deployments
