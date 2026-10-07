---
title: Blog series on partitioning and parallel processing
type: source
status: maintained
tags: [partitioning, parallel, oracle]
created: 2026-10-01
updated: 2026-10-02
sources: [blog.md, posts/]
---

# Blog series on partitioning and parallel processing

Five posts from [rammpeter.blogspot.com](../usage/rammpeter-blog.md) between 2019 and 2024 about two mechanisms
that make large volumes of data manageable — and about how quietly they fail when
one prerequisite is missing.

## The posts

| Date | Title | Focus |
|---|---|---|
| 2019-11-10 | List tables suitable for partition exchange | [Partitioning](../usage/partitioning.md) |
| 2021-05-29 | Run a rolling window over interval partitioned tables / avoid ORA-14300, ORA-14758 | [Interval partitions and the rolling window](../usage/interval-partitions-rolling-window.md) |
| 2023-12-19 | Find SQLs that are missing partition pruning even if it could be possibly used | [Partition pruning](../usage/partition-pruning.md) |
| 2024-02-01 | Find SQLs where expected parallel DML or direct load does not work | [Parallel execution](../usage/parallel-execution.md) |
| 2024-08-20 | Speedup parallel HASH JOIN BUFFERED by using HASH JOIN SHARED | [Parallel execution](../usage/parallel-execution.md) |

## Key points

**Partition exchange is a structural dependency nobody sees.** It requires
identical column *and* index structure, with all indexes of the partitioned table
locally partitioned. The post of 2019-11-10 finds all structurally identical
pairs — explicitly *before* you change a structure and thereby destroy an
operation you did not know about → [Partitioning](../usage/partitioning.md).

**Interval partitions have an upper limit of 1,048,575 — and it is not the
existing ones that count.** What counts is the number of *possible* partitions
between the first range partition and the highest interval partition. With a
one-minute interval that is roughly **1.9 years**, then comes `ORA-14300`
(2021-05-29) → [Interval partitions and the rolling window](../usage/interval-partitions-rolling-window.md).

**The obvious remedy fails as well.** Simply dropping the first range partition
yields `ORA-14758`. The post therefore develops **two** detours via splitting or
merging empty partitions — the second one also works for 12.1
→ [Interval partitions and the rolling window](../usage/interval-partitions-rolling-window.md).

**Partition pruning can fail even though the partition key is in the filter** —
for instance when it is hidden behind a conversion function or compared with a
function result only known at execution time. Often a tiny change to the SQL is
enough (2023-12-19) → [Partition pruning](../usage/partition-pruning.md).

**Parallel DML and direct load are silently ignored** — and the database says
why: in `OTHER_XML` under `pdml_reason` and `idl_reason` respectively
(2024-02-01) → [Parallel execution](../usage/parallel-execution.md).

**An undocumented feature against expensive hash joins.** Parallel Shared Hash
Join (from 18c) lets PQ processes share their hash tables instead of each keeping
its own — less memory, less spilling to TEMP (2024-08-20)
→ [Parallel execution](../usage/parallel-execution.md).

## Notes on the evidence

**Two solutions with precisely stated release validity.** The post of 2021-05-29
documents both detours with the partition listings after each step and states
clearly where the boundary lies: the split route works for 19c and 12.2 but
**not for 12.1** (there always `ORA-14080`, even with PSU April 2021); the merge
route also works for 12.1.0.2. Plus the practical hint to shift the high value by
±1 second on `ORA-14080` to work around rounding issues.

**Two variants depending on the licence.** The check queries of 2023-12-19 come
in duplicate: one using the AWR history (Diagnostics Pack required, sorted by the
time spent on the partition access plan lines) and one using only the SGA (also
for Standard Edition, sorted by the total runtime of the SQL). This pattern — the
same analysis twice, depending on licensing — runs through the whole blog.

**An explicitly unofficial feature with usage limits.** On the shared hash join
the author records: not officially documented, therefore **not in RAC
environments** with PQ operations spread across instances
(`parallel_force_local=FALSE`), and `HASH JOIN OUTER BUFFERED` **cannot** be
transformed up to at least 19.24.

**Prior work by others named:** Randolf Eberle-Geist for the background of the
shared hash join, plus a reference to Chinar Aliyev.

## Source files

`raw/posts/41-*`, `47-*`, `55-*`, `57-*`, `60-*`
