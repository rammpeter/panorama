---
title: Indexing
type: concept
status: draft
tags: [core, index, oracle]
created: 2026-10-01
updated: 2026-10-04
sources: [blog.md, posts/, speakerdeck.md, speakerdeck/]
---

# Indexing

An index in an Oracle database can serve exactly four purposes. If it serves none
of them, it is dispensable — and that is the case more often than practice cares
to admit.

## Summary

Creating an index is very easy measured against its impact; dropping one again is
far harder, because nobody wants to take responsibility for it really not being
needed any more. The result: almost every database system maintains indexes it
does not need, in extreme cases more than half of the total storage requirement
([Blog series on indexing](../sources/blog-indexing.md), 2019-12-27).

The benefit of clearing up is manifold: less storage, less effort for index
maintenance on every DML, better use of the DB cache and consequently better
runtime and response time behaviour of the applications.

> Conclusion (taken from the source): removing superfluous indexes is one of the
> few levers that reduce storage requirement *and* system load substantially
> without any change to the application.

## The four roles of an index

The checklist the whole analysis builds on ([Blog series on indexing](../sources/blog-indexing.md), 2019-12-27):

1. **Optimise access from user SQL** — restrict the result set before table data
   is read. Verified via [Index usage monitoring](index-usage-monitoring.md).
2. **Guarantee uniqueness** — as a unique index or as the carrier of a unique or
   primary key constraint. Recognisable from the `UNIQUENESS` column.
3. **Protect a foreign key** — prevent full table scans on the referencing table
   and the propagation of DML locks. See [Foreign keys and locks](foreign-key-locks.md); whether that is
   necessary at all is covered by [Do not blanket-index foreign keys](do-not-blanket-index-foreign-keys.md).
4. **Establish structural identity for partition exchange** — the table to be
   exchanged in must be indexed identically to the partitioned target table.
   See [Partitioning](partitioning.md).

Conversely: if an existing index fulfils none of these four roles, it can be
removed.

## Even used indexes can be dispensable

Even with proven usage by user SQL it is worth checking further
([Blog series on indexing](../sources/blog-indexing.md), 2019-12-27):

- The columns are already covered by the *leading* columns of a multi-column
  index — the other index takes over the function.
- The table's partitioning has the same filtering effect. If the partitioning
  criterion is unique, restriction via partitions is more effective than an index
  access.
- Changing the column order of another multi-column index makes an index with
  identical leading columns superfluous.
- An access via index fast full scan can also be performed via another index of
  the table, if the relevant columns appear there as well or — as with
  `COUNT(*)` — only the count matters.

## Why it does not happen in practice

Four reasons from [Blog series on indexing](../sources/blog-indexing.md) (2019-12-27) that explain why this lever
regularly goes unused:

- There is no role in the project or product that would own this task.
- DBAs have only limited insight into the application logic of the software.
- Developers lack the knowledge and the tooling for a reliable assessment.
- "Never touch a running system" — dropping carries a latent risk.

## Relationships

- The measurement technique for role 1 is in [Index usage monitoring](index-usage-monitoring.md).
- Role 3 rests on [Foreign keys and locks](foreign-key-locks.md); the position on it is recorded in
  [Do not blanket-index foreign keys](do-not-blanket-index-foreign-keys.md).
- Whoever keeps an index can often shrink it → [Index compression](index-compression.md).
- An index that exists and is used can still work badly →
  [Index access paths](index-access-paths.md), [Extended statistics](extended-statistics.md). The procedure for the first
  case: [Finding skipped index columns](../syntheses/finding-skipped-index-columns.md).
- [Panorama](panorama.md) evaluates all four roles together in one list; the system-wide
  scans for it are in [Dragnet Investigation](dragnet.md).
- Shrinking an index that must stay: [Function-based indexes](function-based-indexes.md),
  [Index compression](index-compression.md). The stance behind the whole topic:
  [Proactive performance tuning](proactive-performance-tuning.md).

## Open questions

- Is there a reliable order in which to check the four roles, so as to rule one
  out as early as possible?
- Role 2 has a special case worth noting from the source: a multi-column unused
  unique index can be removed without problems if the uniqueness of a single
  column of it is already ensured by another unique index or constraint.

## Sources

- [Blog series on indexing](../sources/blog-indexing.md)
- [Talks on indexes](../sources/talks-indexes.md)
