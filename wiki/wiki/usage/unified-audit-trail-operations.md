---
title: Unified audit trail – operations
type: concept
status: draft
tags: [audit, storage, cloud, oracle]
created: 2026-10-01
updated: 2026-10-02
sources: [blog.md, posts/]
---

# Unified audit trail – operations

Two connected posts: why `UNIFIED_AUDIT_TRAIL` can become unusably slow, and how
to keep it permanently small without losing audit records too early.

## Why the view becomes slow

([Blog series on the audit trail](../sources/blog-audit-trail.md), 2025-01-17) After migrating instances to the Exadata Cloud
Service in the OCI cloud, even simple queries on `UNIFIED_AUDIT_TRAIL` no longer
completed in acceptable time.

**The chain of evidence:**

1. The execution plan shows: almost the entire time goes into a **full table scan
   on `X$UNIFIED_AUDIT_TRAIL`**.
2. The wait events captured by [ASH](ash.md) for that plan line name
   `Disk file operations I/O`.
3. That is revealing: `X$` tables are normally the SQL interface to internal
   **memory structures**. Here the table behaves like a wrapper around **file
   structures on disk**.

**The explanation** — supported by a note in the documentation: if the database is
writable, audit records go into the table. If it is **not** writable — typically
closed or read-only as with Active Data Guard — Oracle writes them into
**spillover files** (`.BIN`) in the operating system directory
`$ORACLE_BASE/audit/$ORACLE_SID`. And those files are surfaced in the view as
well.

So the view has **two sources**:

| Source | Content |
|---|---|
| `audsys.AUD$UNIFIED` | records from the time the database was writable |
| `sys.X$UNIFIED_AUDIT_TRAIL` | records from the file system (across RAC: `GV$UNIFIED_AUDIT_TRAIL`) |

**In the concrete case:** the database had been cloned from a standby instance
that had many unified audit policies and very many read-only connections. Several
million audit records consequently sat in the file system.

The one-off remedy was a `DBMS_AUDIT_MGMT.CLEAN_AUDIT_TRAIL`.

> The transferable lesson: checking the amount of data in `audsys.AUD$UNIFIED` is
> not enough. A cloned or temporarily read-only database can bring its audit load
> along in the file system.

## Housekeeping with two hard limits

([Blog series on the audit trail](../sources/blog-audit-trail.md), 2025-01-28) The requirement from a project:

- **hard:** audit records must in all cases remain for at least *x* days.
- **hard:** the stored volume must not exceed a size limit — unless the age rule
  demands it.
- **soft:** as long as the size limit is not reached, records should remain as
  long as possible.

**The problem:** `DBMS_AUDIT_MGMT.CLEAN_AUDIT_TRAIL` can only cut at a
**timestamp**, not at a size.

> The consequence of relying on that alone: you would have to estimate a maximum
> age that holds the size limit even in the worst case — and thereby purge "far
> too early" outside that peak case. Space that is there goes unused.

**The solution** recomputes the time boundary each time:

1. Fetch `Avg_Row_Len` of `audsys.AUD$UNIFIED` from `DBA_TABLES`. If the value is
   missing, the script aborts with a clear message — the table has to have been
   analysed.
2. From that, compute the maximum permissible row count for the size limit.
3. Current row count and oldest timestamp from `UNIFIED_AUDIT_TRAIL` — that is,
   **including** the file system records.
4. If the count is above the limit and records older than the minimum retention
   exist: determine via `ROWNUM` the timestamp from which purging is allowed,
   then `SET_LAST_ARCHIVE_TIMESTAMP` and `CLEAN_AUDIT_TRAIL` with
   `use_last_arch_timestamp => TRUE`.

Every step is logged, including the case "size limit exceeded, but all audit
records are younger than the age threshold — nothing to purge".

### Two hints from the source

**Adjust the partition interval.** If the period to be purged is larger than a
partition interval of `audsys.AUD$UNIFIED`, `CLEAN_AUDIT_TRAIL` uses
`DROP PARTITION` instead of `DELETE` — the far more efficient route. For that the
interval should be **smaller than the call cycle** of the script, settable via
`DBMS_AUDIT_MGMT.ALTER_PARTITION_INTERVAL`. Oracle's default of one month is
"too coarse in most cases".

**The size limit is a net size.** The calculation uses `Avg_Row_Len` × row count.
The space actually allocated is higher — because of `PCTFREE`, LOB indexes and
the possibly nearly empty oldest partition.

## Relationships

- The operations side of [Audit trail](audit-trail.md).
- The diagnosis relies on [ASH](ash.md) (wait events per plan line) and
  [Execution plans](execution-plans.md).
- Another case in which a cloud environment showed unexpected behaviour:
  [LOGON trigger](logon-trigger.md).
- The partition strategy when purging: [Partitioning](partitioning.md).

## Open questions

- Can a cloned database be prevented from bringing the source's spillover files
  along?
- How large is the difference between net and gross size in practice? The source
  names the factors but does not quantify them.
- At what cycle should the script run? The source presupposes a cycle but
  recommends none.

## Sources

- [Blog series on the audit trail](../sources/blog-audit-trail.md)
