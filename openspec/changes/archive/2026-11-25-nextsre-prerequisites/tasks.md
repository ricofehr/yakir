# Tasks

## 1. Tracing & Logcollect Updates

- [x] 1.1 Update `ansible/roles/tracing/templates/tempo-networkpolicy.yml.j2` to admit port 3200 ingress from the `nextsre` namespace and verify template syntax.
- [x] 1.2 Update `ansible/roles/logcollect/tasks/main.yml` to annotate `loki-basic-auth` secret with Reflector mirroring annotations for `nextsre` and verify task definition.

## 2. Monitoring Updates (Alertmanager & Prometheus)

- [x] 2.1 Add Alertmanager webhook bearer token secret generation and volume mount in `ansible/roles/monitoring/tasks/main.yml`.
- [x] 2.2 Configure `nextsre` webhook receiver and alert route in Alertmanager configuration values in `ansible/roles/monitoring/tasks/main.yml`.
- [x] 2.3 Add Prometheus alerting rules for core Kubernetes workload health (`KubePodCrashLooping`, `KubePodNotReady`) in `ansible/roles/monitoring`.

## 3. GitOps & Admission Policy Updates

- [x] 3.1 Update `ansible/roles/gitops/defaults/main.yml` to add `nextsre` to the permitted destination namespaces.
- [x] 3.2 Add `nextsre-k8s-write-scope` ValidatingAdmissionPolicy and binding templates in `ansible/roles/gitops` and register them in `main.yml`.

## 4. Verification

- [x] 4.1 Run `ansible-lint` across the modified roles to verify playbooks and tasks are clean.
- [x] 4.2 Run `openspec validate nextsre-prerequisites --strict` to verify all spec artifacts are valid and complete.
