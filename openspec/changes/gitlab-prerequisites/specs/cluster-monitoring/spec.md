# Spec Delta

## Purpose

Keeps the cluster's Grafana available across deploys and upgrades.

## ADDED Requirements

### Requirement: Grafana rolls out on its single volume
Grafana SHALL run one replica with the `Recreate` strategy, because its dashboards volume
is ReadWriteOnce.

#### Scenario: Upgrade
- **WHEN** the monitoring role changes Grafana's values
- **THEN** the old pod stops before the new one starts, and the new one becomes Ready
