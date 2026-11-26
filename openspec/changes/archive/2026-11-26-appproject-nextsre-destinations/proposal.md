# Proposal

## Why
When NextSRE is deployed via Argo CD (`apps/nextsre.yaml` in `ai-factory`), it creates read-only RBAC roles and rolebindings in watched workload namespaces (such as `prod-hello`). Because the root `AppProject/ai-factory` destinations only permit factory-managed namespaces, Argo CD blocked syncing these roles with `namespace prod-hello is not permitted in project 'ai-factory'`. Adding watched application namespaces to the AppProject destinations ensures full GitOps synchronization while preserving strict cluster resource whitelisting.

## What Changes
- Define `gitops_watched_app_namespaces` in `ansible/roles/gitops/defaults/main.yml` with default `["prod-hello"]`.
- Define `gitops_project_destinations` combining factory-managed namespaces with watched application namespaces.
- Update `ansible/roles/gitops/templates/app-project.yml.j2` to use `gitops_project_destinations` for `spec.destinations`, while keeping `spec.clusterResourceWhitelist` strictly scoped to factory-managed `gitops_project_namespaces` (so `ai-factory` cannot adopt or manage external workload namespaces).

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `nextsre-platform-prereqs`: Add requirement that watched workload namespaces are permitted destinations in the root GitOps AppProject.

## Impact
- `ansible/roles/gitops/defaults/main.yml` and `ansible/roles/gitops/templates/app-project.yml.j2`.
- Argo CD `AppProject/ai-factory` on cluster will permit deploying NextSRE read-only RBAC into `prod-hello`.
