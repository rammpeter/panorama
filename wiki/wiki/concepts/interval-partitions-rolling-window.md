---
title: Interval partitions and the rolling window
type: concept
status: draft
tags: [partitioning, oracle]
created: 2026-10-01
updated: 2026-10-02
sources: [blog.md, posts/]
---

# Interval partitions and the rolling window

Interval partitioning creates new partitions automatically. For a rolling window
— new data arrives at the top, old data is dropped at the bottom — that is ideal,
until it hits a limit that is not where you expect it.

## The limit

([[blog-partitioning]], 2021-05-29) The number of partitions must not exceed
**1,048,575** (= 1024 × 1024 − 1). What is decisive, however:

> What counts is **not** the physically existing partitions but the number of
> **possible** partitions between the originally created first range partition
> and the highest interval partition — measured against the interval in use.

With an interval of one minute that lasts for roughly **1.9 years**. After that:
`ORA-14300` (*partitioning key maps to a partition outside maximum permitted
number of partitions*).

The insidious thing about the rolling window: old partitions are dropped at the
bottom, but the **initial range partition stays** — and moves ever further from
the upper bound. The distance grows even though the data volume stays constant.

## Why the obvious solution fails

Simply dropping the first range partition:

```sql
ALTER TABLE MyTab DROP PARTITION MIN;
```

→ `ORA-14758` (*Last partition in the range section cannot be dropped*).

The author rejects two further routes:

- **Online redefinition of the partitioning rule** (`ALTER TABLE … MODIFY
  PARTITION BY … ONLINE`, from 19c): causes a lot of physical data movement with
  possible impact on the interval partitions in use — and does not work with
  Oracle 12 or below.
- **Temporarily disabling interval partitioning**, dropping, re-enabling: does
  not sit well with the requirement for uninterrupted availability.

## The key idea

`ORA-14758` says the *last* range partition cannot be dropped. From that follows:
if there are **several** range partitions below the interval partitions, any of
them except the last can be dropped.

So you have to turn an interval partition into a pure range partition.

## Route 1: split (19c and 12.2)

1. **Force an empty interval partition below the existing ones** — via an
   `INSERT` with a suitable value, followed by `ROLLBACK`. The partition stays,
   the row does not.
2. **Split that partition.** The split turns the interval partition into two pure
   range partitions.
3. Drop the original range partition with the problematic high value — now
   possible.
4. Drop one of the two split partitions; the other is now the only pure range
   partition, with the lowest high value.

**Two hints from the source:**

- The high value for the split must be **exactly** the high value of the lowest
  interval partition minus the interval.
- On `ORA-14080` (*partition cannot be split along the specified high bound*),
  try ±1 second to work around rounding issues.

**Limit:** works for 19c and 12.2, **not for 12.1** — there
`ALTER TABLE SPLIT PARTITION` on the oldest interval partition always leads to
`ORA-14080`, even with 12.1.0.2 and PSU April 2021.

## Route 2: merge (12.1 too)

1. **Force two adjacent empty interval partitions** — two `INSERT`s exactly one
   interval apart, then `ROLLBACK`.
2. **Merge those two.** The merge turns the combined partition into a pure range
   partition.
3. Drop the original range partition.
4. Rename the merged partition — it is now the only range partition with the
   lowest high value.

Works with 12.1.0.2 as well.

## What both routes have in common

> Neither of them touches the **existing** interval partitions — apart from
> possible effects on global indexes in older releases. That is precisely their
> advantage over online redefinition.

The shared pattern is elegant: an `INSERT` with `ROLLBACK` serves solely to make
Oracle create a partition; split or merge change its type; then dropping is
permitted.

## Relationships

- Part of [[partitioning]].
- The partition interval also decides the efficiency of purging →
  [[unified-audit-trail-operations]].

## Open questions

- What effects on global indexes exactly, and from which release do they
  disappear? The source mentions them only in passing.
- How often does the operation have to be repeated for a running rolling window —
  is there a rule of thumb depending on the interval?
- Does the restriction apply unchanged in 21c and 23ai?

## Sources

- [[blog-partitioning]]
