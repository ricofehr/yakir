# Design

## Context
See `proposal.md` for motivation. In `ansible/roles/gitops/`, the `app-project.yml.j2` template generates the root `AppProject/ai-factory` resource. Currently:
- `spec.destinations` iterates over `gitops_project_namespaces`.
- `spec.clusterResourceWhitelist` iterates over `gitops_project_namespaces` for `kind: Namespace`.

NextSRE in `ai-factory` deploys read-only RBAC (`Role` and `RoleBinding`) into watched application namespaces (such as `prod-hello`).

## Goals / Non-Goals

**Goals:**
- Permit Argo CD `ai-factory` AppProject to deploy resources to watched application namespaces (`prod-hello`).
- Prevent `ai-factory` from acquiring cluster-scoped management/adoption privileges over external workload namespaces.
- Keep Ansible default variables cleanly separated between factory-managed namespaces and external watched namespaces.

**Non-Goals:**
- Creating or managing external workload namespaces (workloads manage their own namespaces).
- Expanding write permissions beyond NextSRE's read-only RBAC requirements.

## Decisions

### Decision 1: Split `destinations` and `clusterResourceWhitelist`
- **Choice**: Introduce `gitops_watched_app_namespaces` (default `['prod-hello']`) and combine it with `gitops_project_namespaces` into `gitops_project_destinations`.
- **Rationale**: `spec.destinations` needs `prod-hello` so Argo CD admits namespaced resources (Role, RoleBinding) deployed by `ai-factory`. `spec.clusterResourceWhitelist` strictly uses `gitops_project_namespaces` (the factory's own managed namespaces) so `ai-factory` cannot adopt or alter external workload namespaces.
- **Alternative considered**: Appending `prod-hello` directly to `gitops_app_namespaces` or `gitops_project_namespaces`. Rejected because `gitops_app_namespaces` are automatically created by Ansible tasks with baseline Pod Security, and `clusterResourceWhitelist` would expose `Namespace` mutation for `prod-hello`.

## Risks / Trade-offs

- **[Risk] Adding another watched namespace later requires a GitOps update**:
  → *Mitigation*: Centralized in `gitops_watched_app_namespaces` list variable in Ansible defaults, easily extensible or overridable.
