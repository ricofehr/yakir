# factory-bootstrap Specification

## Purpose
Defines what yakir's gitops role hands the ai-factory: the namespaces it pre-creates, the
credentials it seeds there, the envelope Argo CD may apply into, and how soon a commit lands.

## Requirements

### Requirement: GitLab's namespace and credentials are bootstrapped
The gitops role SHALL create the `ai-gitlab` namespace and seed `valkey-auth` (generated
once, then reused) and `gitlab-backup-offsite` (MinIO endpoint, GitLab user's keys,
crypt passphrase from `--gitlab-backup-passphrase-file`). The latter is written only when
the backup server, the MinIO admin credentials file and the passphrase file are all given.

#### Scenario: First deploy
- **WHEN** the gitops role runs on a fresh cluster with the backup server, the MinIO admin credentials file and the passphrase file
- **THEN** `ai-gitlab` exists with Pod Security `baseline`, and holds `valkey-auth` (key `default`) and `gitlab-backup-offsite` (keys `endpoint`, `access-key`, `secret-key`, `crypt-passphrase`)

#### Scenario: Replay
- **WHEN** the gitops role runs again
- **THEN** `valkey-auth` keeps its value

#### Scenario: No passphrase file
- **WHEN** the role runs without the passphrase or admin credentials file
- **THEN** `gitlab-backup-offsite` is not written and the run says so, rather than storing an empty passphrase

#### Scenario: Only some of the off-site flags
- **WHEN** `deploy-to-libvirt` is given the passphrase or admin credentials file without the others, or without `--backup-server`
- **THEN** it stops before terraform, naming the flags that go together

### Requirement: The AppProject admits only what the factory deploys
The ai-factory AppProject SHALL list `ai-gitlab` among its destinations, and SHALL NOT list
`kube-system`, the cert-manager namespace or `arc-system`. Its cluster-resource whitelist
SHALL admit `ValidatingAdmissionPolicy` and `ValidatingAdmissionPolicyBinding`, and SHALL
NOT admit `ClusterIssuer` or `APIService`.

#### Scenario: Rendering the project
- **WHEN** `app-project.yml.j2` is rendered with the role's defaults
- **THEN** the destinations and whitelist match the requirement

### Requirement: Retired credentials are no longer seeded
The gitops role SHALL NOT create the `ai-devpods` namespace, the OVH DNS-01 credential or
the GitHub App credential, and `deploy-to-libvirt` SHALL NOT accept the flags that supplied
the last two.

#### Scenario: An old flag is passed
- **WHEN** `deploy-to-libvirt` is called with `--ovh-credentials-file` or `--github-app-key`
- **THEN** it rejects the unknown option before terraform runs

### Requirement: Argo CD picks up a commit within a minute
Argo CD SHALL poll the factory repository every 60 seconds.

#### Scenario: A merge on main
- **WHEN** a commit lands on the tracked branch
- **THEN** the affected applications reconcile against it within about a minute, without a manual refresh
