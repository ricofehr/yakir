# v1.5

## Changes by Kind

### Improvement

- Add a gitops role deploying Argo CD and the CloudNativePG operator, and register the ai-factory root application
- Bootstrap the credentials the Argo CD applications cannot generate for themselves: git deploy key, LiteLLM master key, local model api key, GitHub App for the self-hosted runners
- Generate the LiteLLM master key once and reuse it on replays, so issued virtual keys survive a re-run
- Skip the gitops role entirely while gitops_repo_url is empty, leaving a plain cluster install unchanged
- Expose the gitops settings through up and deploy-to-libvirt (--gitops-repo, --gitops-branch, --gitops-ssh-key, --llama-api-key, --github-app-id, --github-app-installation-id, --github-app-key)
- Raise the libvirt worker sizing to 12Go, the headroom the ai-factory workloads need on top of rook-ceph and the monitoring stack

### Bug Fix

- Pass the ansible extra-vars of up and deploy-to-libvirt as arrays, replacing the eval in up: a value containing a space, a glob character or a $ was split, expanded or silently truncated on its way to ansible
- Create every ai-factory namespace at bootstrap, so the wave 0 database application no longer deadlocks writing into namespaces whose own application syncs in wave 3
- Publish the LiteLLM master key to both namespaces that consume it, since a secretKeyRef cannot cross a namespace
- Keep a stored local model api key and GitHub token on a replay that does not re-supply them, instead of overwriting a working credential with a placeholder
- Create the GitHub token unconditionally: the MCPServer CRD has no optional flag on a secret reference, so the github MCP server could not start without it
- Give the waits an until condition, without which ansible ignores retries entirely
- Scope the Argo CD root application to its own AppProject rather than default, which permits any destination and any resource kind
- Drop the unused MIRROR_APT_PARAM and MIRROR_PYPI_PARAM assignments from up
