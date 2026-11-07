# git-ssh-ingress Specification

## Purpose
Carries Git over SSH from outside the cluster to the factory's GitLab, through the same
VIP and HAProxy path as HTTP.

## Requirements

### Requirement: Port 2222 on the VIP reaches Traefik's gitlab-shell entrypoint
HAProxy on the managers SHALL forward TCP 2222 to Traefik's `gitlab-shell` entrypoint,
which Traefik SHALL expose on NodePort 30022.

#### Scenario: SSH handshake
- **WHEN** a client opens TCP to the VIP on port 2222 and GitLab is deployed
- **THEN** it gets gitlab-shell's SSH banner

#### Scenario: Rendering HAProxy
- **WHEN** `haproxy.cfg.j2` is rendered
- **THEN** it has a frontend binding `*:2222` whose backend points at the ingress node port 30022
