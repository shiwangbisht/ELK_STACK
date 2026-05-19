# Elasticsearch Unassigned Shard Recovery After Snapshot Restore

This repository contains a production-safe approach to analyze and recover unassigned shards in Elasticsearch after snapshot restoration or index migration.

The workflow is designed to:
- Safely analyze unassigned shards
- Test restoration on a single index first
- Restore indices in batches with verification
- Avoid accidental data loss
- Provide rollback-friendly operations
- Maintain production safety standards

---

# Common Scenarios

This approach is useful when:
- Snapshot restore completed partially
- Indices show `UNASSIGNED` shards
- Cluster health becomes `yellow` or `red`
- Elasticsearch node migration was performed
- Storage corruption happened
- Cross-cluster migration caused missing shards
- Manual snapshot restoration failed

---

# Repository Structure

```bash
.
├── README.md
├── scripts/
│   ├── analyze_unassigned.sh
│   ├── test_restore.sh
│   └── safe_restore.sh
```

---

# Production-Safe Recovery Approach

---

# Step 1 — Analyze Unassigned Shards

This step performs analysis only.

No changes are made to the cluster.

## Purpose
- Identify affected indices
- Count unassigned shards
- Validate recovery scope before execution

## Run

```bash
chmod +x scripts/analyze_unassigned.sh

./scripts/analyze_unassigned.sh \
"https://localhost:9200" \
"elastic" \
"password" \
"index-prefix-*"
```

## Example

```bash
./scripts/analyze_unassigned.sh \
"https://localhost:9200" \
"elastic" \
"MySecretPassword" \
"logs-*"
```

---

# Step 2 — Test Restore on Single Index

Always validate restoration on one index before running bulk recovery.

## Purpose
- Validate snapshot accessibility
- Ensure recovery works correctly
- Verify index health transition

## Run

```bash
chmod +x scripts/test_restore.sh

./scripts/test_restore.sh \
"https://localhost:9200" \
"elastic" \
"password" \
"snapshot_repo" \
"snapshot_name" \
"index_name"
```

## Example

```bash
./scripts/test_restore.sh \
"https://localhost:9200" \
"elastic" \
"MySecretPassword" \
"backup_repo" \
"daily_snapshot" \
"logs-2026.05.10"
```

---

# Step 3 — Batch Restore Unassigned Indices

This script safely restores all indices with unassigned shards.

## Features

- Production-safe execution
- Logging support
- Confirmation prompt
- Index existence verification
- Automatic reroute retry
- Final health validation
- Failure tracking
- No hardcoded values

---

# Run

```bash
chmod +x scripts/safe_restore.sh

./scripts/safe_restore.sh \
"https://localhost:9200" \
"elastic" \
"password" \
"snapshot_repo" \
"snapshot_name" \
"index-prefix-*"
```

---

# Example

```bash
./scripts/safe_restore.sh \
"https://localhost:9200" \
"elastic" \
"MySecretPassword" \
"backup_repo" \
"daily_snapshot" \
"logs-*"
```

---

# Parameters

| Parameter | Description |
|---|---|
| ES_HOST | Elasticsearch endpoint |
| ES_USER | Elasticsearch username |
| ES_PASS | Elasticsearch password |
| SNAPSHOT_REPO | Snapshot repository name |
| SNAPSHOT_NAME | Snapshot name |
| INDEX_PATTERN | Index pattern to scan |

---

# Recovery Workflow

```text
Analyze Cluster
      ↓
Identify Unassigned Indices
      ↓
Test Restore on One Index
      ↓
Validate Health
      ↓
Run Batch Restore
      ↓
Force Cluster Reroute
      ↓
Verify Cluster Health
```

---

# Best Practices

## Always Test First
Never execute bulk restore directly in production.

---

## Avoid Immediate Delete Operations
Prefer:
- Closing indices
- Restoring safely
- Reopening after validation

---

## Verify Snapshot Availability

Before restoring:

```bash
curl -k -u USER:PASSWORD \
"https://localhost:9200/_snapshot/_all?pretty"
```

---

## Check Cluster Health

```bash
curl -k -u USER:PASSWORD \
"https://localhost:9200/_cluster/health?pretty"
```

---

## Monitor Unassigned Shards

```bash
curl -k -u USER:PASSWORD \
"https://localhost:9200/_cat/shards?v"
```

---

# Common Root Causes of Unassigned Shards

| Cause | Description |
|---|---|
| Missing node | Original shard node unavailable |
| Disk watermark | Disk usage exceeded threshold |
| Corrupted snapshot | Incomplete snapshot restoration |
| Replica allocation issue | Insufficient nodes |
| Version mismatch | Snapshot incompatible |
| Allocation disabled | Cluster routing disabled |
| Missing analyzer/plugin | Plugin unavailable after migration |

---

# Useful Elasticsearch APIs

## Cluster Health

```bash
GET _cluster/health
```

---

## Allocation Explain

```bash
GET _cluster/allocation/explain
```

---

## List Shards

```bash
GET _cat/shards?v
```

---

## Retry Failed Allocation

```bash
POST _cluster/reroute?retry_failed=true
```

---

# Safety Recommendations

- Perform recovery during low traffic windows
- Keep fresh snapshots before restoration
- Validate disk space availability
- Avoid restoring all indices simultaneously in large clusters
- Monitor JVM heap during restore
- Monitor recovery speed and throttling

---

# Requirements

- Bash
- curl
- jq
- Elasticsearch Snapshot Repository configured
- Snapshot already available

---
