# v0.2

## Changes by Kind

### New Feature

- Manage 3 deployment sizing scopes : small (1 master / 2 nodes), medium (1 master / 3 nodes) and large (1 master / 5 nodes)

### Bug or Regression

- Fix Octavia Load-balancer creation during Kubernetes deployment on openstack
- Change k8s apt key id with the updated version for the Kubernetes package repository
- Fix openstack keypair creation with Terraform

### Improvement

- Improve DNS resolving with use of systemd-resolved service
- Ansible rework on Kubelet service part

### Other
