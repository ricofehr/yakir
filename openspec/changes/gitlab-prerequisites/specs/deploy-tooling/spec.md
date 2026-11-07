# Spec Delta

## Purpose

Defines how `deploy-to-libvirt` applies yakir to a cluster, including a live one that only
needs some roles replayed.

## ADDED Requirements

### Requirement: A subset of roles can be applied to a live cluster
`deploy-to-libvirt --ansible-tags <list>` SHALL pass the list to `ansible-playbook --tags`,
leaving every other role untouched.

#### Scenario: Prerequisites on a live cluster
- **WHEN** an operator runs `deploy-to-libvirt … --ansible-tags gitops,csi,ingress,haproxy,monitoring`
- **THEN** only those roles' tasks run, and terraform reports no infrastructure change
