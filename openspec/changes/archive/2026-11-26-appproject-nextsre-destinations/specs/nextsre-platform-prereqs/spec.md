# Spec Delta

## ADDED Requirements

### Requirement: Watched application namespaces permitted in root GitOps project
The root Argo CD AppProject SHALL list NextSRE's watched application namespaces among its destination namespaces while keeping cluster-scoped Namespace creation and adoption restricted to factory-managed namespaces.

#### Scenario: NextSRE read-only RBAC synced into watched namespace
- **WHEN** an Argo CD Application deploys a Role and RoleBinding into a watched application namespace (e.g. `prod-hello`)
- **THEN** the root AppProject permits the destination without authorization error

#### Scenario: External namespace adoption is rejected
- **WHEN** an Argo CD Application attempts to define or adopt a Namespace resource for an external application namespace
- **THEN** the root AppProject rejects the cluster-scoped Namespace resource
