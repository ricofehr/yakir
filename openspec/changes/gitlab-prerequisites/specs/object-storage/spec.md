# Spec Delta

## Purpose

Lets cluster workloads get Ceph RGW buckets and S3 users declaratively, through the
cluster's bucket StorageClass and object-store users.

## ADDED Requirements

### Requirement: The bucket StorageClass provisions on the real store
The `rook-ceph-bucket` StorageClass SHALL name the object store yakir creates (`my-store`).

#### Scenario: A bucket claim
- **WHEN** an ObjectBucketClaim names `rook-ceph-bucket`
- **THEN** a bucket is created on `my-store` and the claim binds

### Requirement: The factory can own its buckets
The object store SHALL allow CephObjectStoreUsers in `ai-gitlab`, and the operator SHALL
accept the `bucketOwner` claim field alongside `maxObjects` and `maxSize`.

#### Scenario: GitLab's storage
- **WHEN** ai-factory creates `CephObjectStoreUser/gitlab` in `ai-gitlab` and claims with `bucketOwner: gitlab`
- **THEN** Rook creates the user with its key secret in `ai-gitlab`, and the buckets are owned by it
