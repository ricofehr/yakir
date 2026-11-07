# Spec Delta

## Purpose

Provides the bucket outside the cluster that GitLab's backups are copied to, set up without
manual steps and out of reach of anything running in the cluster.

## ADDED Requirements

### Requirement: The off-site bucket is versioned and expires on a schedule
The gitops role SHALL ensure the `gitlab-backups` bucket exists on the `--backup-server`
MinIO, with versioning on and a lifecycle rule expiring current objects after 90 days and
noncurrent versions after 30 days.

#### Scenario: Replay
- **WHEN** the role runs against a MinIO where the bucket already exists
- **THEN** the bucket, its versioning and its single lifecycle configuration are unchanged, not duplicated

### Requirement: Archives cannot be purged by overwriting them
The bucket SHALL be created with object lock and a default GOVERNANCE retention of the
retention period, so a version replaced by an overwrite stays until its retention ends.

#### Scenario: Overwrite with the GitLab key
- **WHEN** a client using the GitLab key overwrites an existing archive
- **THEN** the original version is still retained, and neither that client nor an admin without governance bypass can delete it before its retention ends

#### Scenario: Pre-existing bucket without object lock
- **WHEN** the role finds `gitlab-backups` already existing without object lock
- **THEN** the run fails, saying object lock can only be enabled at creation

### Requirement: The admin credential never enters the cluster
The MinIO admin credential used to set up the store SHALL come from a file on the controller
(`--minio-admin-credentials-file`) and SHALL NOT be written to any cluster Secret.

#### Scenario: Inspecting the cluster after a run
- **WHEN** an operator lists the Secrets the gitops role wrote
- **THEN** none holds the MinIO admin key

### Requirement: The GitLab backup user cannot delete
The GitLab backup user SHALL be able to list the bucket and read and write objects in it,
and SHALL NOT be able to delete objects or change the bucket's configuration.

#### Scenario: Delete attempt with the GitLab key
- **WHEN** a client using `gitlab-backup-offsite`'s keys deletes an object in `gitlab-backups`
- **THEN** MinIO refuses with AccessDenied

### Requirement: A rebuilt cluster regains access without manual steps
The GitLab user's secret SHALL be generated once per cluster, stored in
`gitlab-backup-offsite`, and re-applied to MinIO on every run, so a rebuilt cluster with a
new secret keeps working.

#### Scenario: Rebuild
- **WHEN** the gitops role runs on a fresh cluster against a MinIO where the user already exists
- **THEN** the user's secret is reset to the newly stored one, and the old cluster's key stops working
