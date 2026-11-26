# Tasks

## 1. AppProject Destination Configuration

- [x] 1.1 Add `gitops_watched_app_namespaces` and `gitops_project_destinations` in `ansible/roles/gitops/defaults/main.yml` and verify YAML syntax
- [x] 1.2 Update `ansible/roles/gitops/templates/app-project.yml.j2` to use `gitops_project_destinations` for `spec.destinations` while retaining `gitops_project_namespaces` for `spec.clusterResourceWhitelist`
- [x] 1.3 Verify template rendering via ansible-lint / dry-run and confirm output preserves exact structure
