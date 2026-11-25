# Spec Delta

## Purpose

Provides platform-level security boundaries, credential reflection, and admission controls required for the NextSRE agent system to run safely on the cluster.

## ADDED Requirements

### Requirement: Loki credentials reflected to NextSRE
The Loki basic authentication Secret in `kube-logcollect` SHALL carry Reflector annotations enabling automatic mirroring into the `nextsre` namespace.

#### Scenario: Secret mirrored to NextSRE namespace
- **WHEN** the `loki-basic-auth` secret is applied or updated in `kube-logcollect`
- **THEN** Reflector copies the secret into the `nextsre` namespace with identical username and password keys

### Requirement: Admission policy bounds Operator write scope
The cluster SHALL enforce a ValidatingAdmissionPolicy that restricts updates made by the `k8s-write` ServiceAccount on Deployments strictly to replica scaling and the `sre-agent/restartedAt` annotation.

#### Scenario: Unauthorized Deployment mutation is denied
- **WHEN** a mutation request on a Deployment arrives from the `k8s-write` ServiceAccount altering the pod template container image or command
- **THEN** the API server denies the update with a policy violation message

#### Scenario: Permitted rolling restart or scaling succeeds
- **WHEN** an update request on a Deployment arrives from the `k8s-write` ServiceAccount modifying only `spec.replicas` or `spec.template.metadata.annotations["sre-agent/restartedAt"]`
- **THEN** the API server admits the update

### Requirement: NextSRE namespace permitted in root GitOps project
The root Argo CD AppProject SHALL list `nextsre` among its destination namespaces.

#### Scenario: NextSRE resources synced by Argo CD
- **WHEN** an Argo CD Application deploys resources into the `nextsre` namespace
- **THEN** the root AppProject permits the destination without authorization error
