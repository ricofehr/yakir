# v1.0

## Changes by Kind

### New Feature

- Cert-manager deployment : manage creation and renew of certificate with an autosigned CA or letsencrypt 
- Propose to use internal mirroring repository for apt (ubuntu) and pypi packages
- Add CSI distributed storage feature with Rook : build Ceph clusters and add storageclass for object, file, and block storages
- Add monitoring stack : prometeheus and grafana with a default k8s dashboard
- Add logging stack : fluentbit service and Kibana dashboard
- Add libvirt deployment for a build of VMs directly on KVMs with Terraform
- Add hardening rules on Linux host systems : kernel configuration, pam and ssh secure settings
- Add backup feature with Velero : by default a Daily backup uploaded in S3 external service (MinIO or Aws S3)

### Bug Fix

### Improvement

- Rework input script parameters : more intuitive naming
- Add ingress entry for Kube dashboard : reachable with FQDN, no more with kube-proxy intermediary
- Remove openstack deployment part : focus on KVM deployment instead
- Add haproxy in front of ingress controller : be able to listen in 443 and 80 ports
- Update Kubernetes to v1.28.1

### Other

- Update and Improvements of README file

