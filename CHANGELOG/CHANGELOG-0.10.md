# v0.10

## Changes by Kind

### New Feature

- Control-plane nodes cluster deployment : 3 manager nodes provisioned
- Add failover ip mechanism for control-plane nodes : keepalived service installation

### Bug or Regression

### Improvement

- Large Ansible refactoring work : improve modularity and idempotency
- Install Flannel with helm repository instead of a one large manifest
- Update weave version : v2.8.1 
- Add ansible.cfg file to define collections folder for this project

### Other

- Improvements and adding text on README file
- Write CHANGELOG files from v0.1 to v0.10 releases
