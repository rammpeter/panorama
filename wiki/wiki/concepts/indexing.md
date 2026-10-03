---
title: Indexing
type: concept
status: draft
tags: [core, index, oracle]
created: 2026-10-01
updated: 2026-10-02
sources: [blog.md, posts/]
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
([[blog-indexing]], 2019-12-27).

The benefit of clearing up is manifold: less storage, less effort for index
maintenance on every DML, better use of the DB cache and consequently better
runtime and response time behaviour of the applications.

> Conclusion (taken from the source): removing superfluous indexes is one of the
> few levers that reduce storage requirement *and* system load substantially
> without any change to the application.

## The four roles of an index

The checklist the whole analysis builds on ([[blog-indexing]], 2019-12-27):

1. **Optimise access from user SQL** — restrict the result set before table data
   is read. Verified via [[index-usage-monitoring]].
2. **Guarantee uniqueness** — as a unique index or as the carrier of a unique or
   primary key constraint. Recognisable from the `UNIQUENESS` column.
3. **Protect a foreign key** — prevent full table scans on the referencing table
   and the propagation of DML locks. See [[foreign-key-locks]]; whether that is
   necessary at all is covered by [[do-not-blanket-index-foreign-keys]].
4. **Establish structural identity for partition exchange** — the table to be
   exchanged in must be indexed identically to the partitioned target table.
   See [[partitioning]].

Conversely: if an existing index fulfils none of these four roles, it can be
removed.

## Even used indexes can be dispensable

Even with proven usage by user SQL it is worth checking further
([[blog-indexing]], 2019-12-27):

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

Four reasons from [[blog-indexing]] (2019-12-27) that explain why this lever
regularly goes unused:

- There is no role in the project or product that would own this task.
- DBAs have only limited insight into the application logic of the software.
- Developers lack the knowledge and the tooling for a reliable assessment.
- "Never touch a running system" — dropping carries a latent risk.

## Relationships

- The measurement technique for role 1 is in [[index-usage-monitoring]].
- Role 3 rests on [[foreign-key-locks]]; the position on it is recorded in
  [[do-not-blanket-index-foreign-keys]].
- Whoever keeps an index can often shrink it → [[index-compression]].
- An index that exists and is used can still work badly →
  [[index-access-paths]], [[extended-statistics]]. The procedure for the first
  case: [[finding-skipped-index-columns]].
- [[panorama]] evaluates all four roles together in one list; the system-wide
  scans for it are in [[dragnet]].

## Open questions

- Is there a reliable order in which to check the four roles, so as to rule one
  out as early as possible?
- Role 2 has a special case worth noting from the source: a multi-column unused
  unique index can be removed without problems if the uniqueness of a single
  column of it is already ensured by another unique index or constraint.

## Sources

- [[blog-indexing]]
