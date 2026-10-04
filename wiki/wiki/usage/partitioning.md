---
title: Partitioning
type: concept
status: draft
tags: [core, partitioning, oracle]
created: 2026-10-01
updated: 2026-10-02
sources: [blog.md, posts/]
---

# Partitioning

Splitting a table into physically separate sections. In the blog it appears not
as an end in itself but through its three practical consequences: partition
exchange, partition pruning and the limits of interval partitions.

## Partition exchange

Swaps an unpartitioned table for a partition of a partitioned table — the fast
way to load or exchange large volumes of data, because only metadata changes.

**The prerequisites** ([[blog-partitioning]], 2019-11-10):

- a partitioned and an unpartitioned table with the **same column structure**
- the **same index structure**
- all indexes of the partitioned table **locally partitioned**

> The reason for the post is not performing the operation but **not destroying
> it**: the information is useful *before* you change a table or index structure
> — so that you know this dependency exists and do not accidentally break a
> working operation.

The query finds all structurally identical pairs system-wide. The trick: per
table a **structure hash** is formed — over `ORA_HASH` of the data type,
multiplied by column position, length, precision and scale — and a second one
over the index columns. Tables with the same hash are candidates.

This is at the same time **role 4** of the four roles in [[indexing]]: an index
may have to exist solely because it establishes the structural identity for
partition exchange.

## The further aspects

- **Partition pruning** — access to one partition instead of a thousand, and why
  it fails → [[partition-pruning]]
- **Interval partitions** — the upper limit of 1,048,575 and the rolling window
  → [[interval-partitions-rolling-window]]
- **Partition strategy when purging** — a suitable partition interval turns a
  `DELETE` into a `DROP PARTITION`, see
  [[unified-audit-trail-operations]]
- **Which partition is running right now?** → [[long-operations]]
- **Partitioning as an index substitute** — if the partitioning criterion has the
  same filtering effect as an index, it is more effective; the index can go
  → [[indexing]]

## Relationships

- Role 4 of the four roles in [[indexing]].
- The column structure check resembles, methodically, the index check in
  [[foreign-key-locks]]: structure decides, not intent.

## Open questions

- The structure hash works with a sum of products — collisions are theoretically
  possible. How reliable is the method?
- Which kind of partitioning fits when? The blog covers range and interval, not
  list or hash.

## Sources

- [[blog-partitioning]]
