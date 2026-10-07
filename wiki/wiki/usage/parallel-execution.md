---
title: Parallel execution
type: concept
status: draft
tags: [parallel, execution-plan, oracle]
created: 2026-10-01
updated: 2026-10-02
sources: [blog.md, posts/]
---

# Parallel execution

Parallel processing fails in three ways in the blog: it is requested and silently
ignored; it runs and thereby distorts the measurement; or it runs inefficiently
because every process works on its own.

## When hints are ignored

([Blog series on partitioning and parallel processing](../sources/blog-partitioning.md), 2024-02-01) If you place `PARALLEL`, `APPEND` and the
like, the database may pass over them for many reasons. The best-known example:
for parallel DML the session has to be enabled beforehand —

```sql
ALTER SESSION ENABLE PARALLEL DML;
```

> "There are lots of similar pitfalls that may prevent the DB from using the
> expected execution path."

**The database says why.** Two information fields sit in the plan's `OTHER_XML`:

| Field | Meaning |
|---|---|
| `pdml_reason` | why parallel DML was not used |
| `idl_reason` | why direct load was not used |

To be read via
`EXTRACTVALUE(XMLTYPE(Other_XML), '/*/info[@type = "pdml_reason"]')`, against
`GV$SQL_PLAN` and `DBA_HIST_SQL_PLAN`. The search is stored in [Dragnet Investigation](dragnet.md) under
point 2.2.12, sorted by execution time.

So the same `OTHER_XML` that in [Optimizer hints](optimizer-hints.md) reports on hint usage also
explains the absence of parallel processing here.

## Parallel shared hash join

([Blog series on partitioning and parallel processing](../sources/blog-partitioning.md), 2024-08-20) A feature present since **18c** and
**undocumented**: parallel query processes share their hash tables instead of
each keeping its own. The memory for that lives in a region of its own, the
**Managed Global Area (MGA)**; Doc ID 2638904.1.

**The benefit** applies particularly to expensive `HASH JOIN BUFFERED` operations
that spill large amounts into the TEMP tablespace: shared hash tables lower the
overall memory requirement, so that more data is processed before spilling.
If the transformation succeeds, the plan shows `HASH JOIN SHARED` instead of
`HASH JOIN BUFFERED`.

**Three ways to switch it on:**

```sql
-- 1. system or session level
ALTER SESSION SET "_px_shared_hash_join" = TRUE;
-- 2. distribution strategy per table in the SQL
/*+ PQ_DISTRIBUTE(<table alias> SHARED NONE) */
-- 3. parameter at SQL level
/*+ OPT_PARAM('_px_shared_hash_join' 'true') */
```

> The author's choice: *"The latter option by OPT_PARAM fits best for me because
> behaviour can be controlled at SQL level without defining it for each table."*
> So route 3 — SQL-precise control without specifying anything per table. Marked
> as a personal preference, not as a measurement result.

**The usage limits — to be taken seriously, because it is undocumented:**

- **Not in RAC environments** where PQ operations are spread across several
  instances (`parallel_force_local = FALSE`).
- `HASH JOIN OUTER BUFFERED` **cannot** be transformed — at least up to release
  19.24.

**Finding candidates:** a query over [ASH](ash.md) lists SQL with
`HASH JOIN BUFFERED`, sorted by the time spent on that plan line, and carries the
maximum TEMP space allocated alongside (`Temp_Space_Allocated`). In [Dragnet Investigation](dragnet.md)
under point 2.2.11.

The author credits Randolf Eberle-Geist for the background.

## Parallel processing as a disturbance

Two places where parallel query distorts the measurement itself:

- **[ASH](ash.md)** does not record the idle wait events of the query coordinator and
  the slaves (`PX Deq Credit: send blkd`, `PX Deq: Execution Msg`) — a busy
  session appears idle.
- **[TEMP usage](temp-usage.md)**: "Max. temp" shows the maximum across coordinator and
  slaves, not their sum.

## Relationships

- The reason fields sit in the same `OTHER_XML` as [Optimizer hints](optimizer-hints.md).
- Spilling to TEMP: [TEMP usage](temp-usage.md).
- The blind spot for idle waits: [ASH](ash.md).
- Licensing caveat for the search queries: [Management pack licensing](management-pack-licensing.md),
  alternatively [Panorama Sampler](panorama-sampler.md).

## Open questions

- What values can `pdml_reason` take, and what do they mean? The source shows how
  to read them, not how to interpret them.
- Is `_px_shared_hash_join` documented by now, or standard in 23ai?
- How large is the gain in numbers? The source describes the mechanism without
  naming a measurement.

## Sources

- [Blog series on partitioning and parallel processing](../sources/blog-partitioning.md)
