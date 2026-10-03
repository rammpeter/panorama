---
title: Partition pruning
type: concept
status: draft
tags: [partitioning, execution-plan, oracle]
created: 2026-10-01
updated: 2026-10-02
sources: [blog.md, posts/]
---

# Partition pruning

Access to *one* partition instead of all. The difference can be enormous —
"imagine you only need to scan one partition of a table instead of several
thousands" ([[blog-partitioning]], 2023-12-19).

## When it fails

Sometimes a SQL scans all partitions **even though** a filter condition contains
the partition key. The source names two causes:

- The partition key is hidden behind a **conversion function**.
- It is compared with a **function result** that is only known at execution time.

## The example

A table `Orders` interval-partitioned by day:

```sql
-- scans all partitions
SELECT SUM(Value) FROM Orders WHERE Day = GetCurrentDay();

-- uses partition pruning
SELECT SUM(Value) FROM Orders WHERE Day = (SELECT GetCurrentDay() FROM DUAL);
```

> The change is as small as can be: the function call moves into a subselect.
> That turns the value into something the optimizer can resolve before the
> access. The author aptly calls such cases "very low hanging fruits".

## Searching system-wide

The check queries look for plan lines where **both** hold at once: the access
goes across all partitions of a partitioned object (`Partition_Start = '1'` in
conjunction with the physical partition count), **and** the partition key — from
`DBA_PART_KEY_COLUMNS` — appears in the access or filter predicates of the
surrounding plan lines. Join operations are excluded.

Two variants, depending on the licence:

| Variant | Source | Sorting | Prerequisite |
|---|---|---|---|
| 1 | SGA **and** AWR history | time on the partition access plan lines (from [[ash]]) | Diagnostics Pack; fully usable from 19.20 |
| 2 | SGA only | total runtime of the SQL (`GV$SQL`) | none — Standard Edition too |

> On the release note: variant 1 works according to the source "especially
> starting with DB release 19.20", because access and filter predicates are only
> captured in the AWR from then on. See the trap in [[execution-plans]] on this —
> without removing the old plans, the columns stay empty even after the upgrade.
> The query carries a `UNION` for that, with the comment that duplicates are
> possible where predicates are unset (before 19.19).

In [[panorama]] via [[dragnet]].

## Relationships

- Part of [[partitioning]].
- Depends on the availability of the predicate columns → [[execution-plans]].
- The same pattern as [[index-access-paths]]: access versus filter predicate
  decides, and the plan looks inconspicuous. Both are placed in context in
  [[finding-skipped-index-columns]].
- Licence variants: [[management-pack-licensing]], [[panorama-sampler]].

## Open questions

- Which conversion functions prevent pruning and which do not? The source names
  the category, not the list.
- Does the subselect trick also work with composite partition keys and with
  subpartitioning?

## Sources

- [[blog-partitioning]]
