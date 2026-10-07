---
title: Foreign keys and locks
type: concept
status: draft
tags: [index, locks, oracle]
created: 2026-10-01
updated: 2026-10-02
sources: [blog.md, posts/]
---

# Foreign keys and locks

A foreign key constraint can cause DML on the *referenced* table to request locks
on the *referencing* table — and thereby block other sessions. Whether an index
on the referencing column has to prevent that depends on which kind of DML
actually occurs.

## Two reasons for an index on the foreign key column

([Blog series on indexing](../sources/blog-indexing.md), 2016-11-25 and 2019-12-27)

1. **Avoid full table scans.** Without an index, a delete on the referenced table
   causes a full table scan on the referencing table for *every deleted row*.
2. **Avoid lock propagation.** Deletes and certain updates on the referenced
   table briefly request a share lock (mode 4) on the referencing table, which
   can collide with DML running there.

## Which kind of DML actually blocks?

The post of 2016-11-25 reproduces eight scenarios with two tables (`Dim` as the
referenced, `Fact` as the referencing table) and measures the lock modes on
releases **11.2, 12.1 and 19.3**. Lock modes: RS = row share (2),
RX = row exclusive (3), S = share (4), X = exclusive (6).

The findings, summarised:

- **Insert on the referenced table does not block.** Under 11.2 both sessions
  still held an RX lock on both tables; from 12.1 it is only an RS lock on
  `Fact`. In no case does blocking occur.
- **Update without the PK column in the SET clause does not block.**
- **Update *with* the PK column in the SET clause** behaved under **11.2** like a
  delete: session 2 requested an S lock on `Fact` and ran into
  `enq: TM - contention`. **From 12.1 that disappears** — session 2 takes no lock
  on `Fact` at all. With an index on `Fact(Dim_ID)` the case was unproblematic
  even under 11.2.
- **Delete on the referenced table blocks** when uncommitted DML is running on
  the referencing table — and that on **all three tested releases**
  (`enq: TM - contention`). With an index the blocking disappears.
- The required share lock is only held at the start of the statement and released
  during the subsequent full table scan.
- A waiting S request in turn blocks subsequent RX requests from third sessions —
  so the blocking propagates.

> Conclusion: the risk concentrates on **deletes** on the referenced table. If
> you treat primary key columns as immutable technical row identities and leave
> them out of the SET clause of updates, the second risk case disappears — and
> from 12.1 it does so anyway.

The position derived from this is in [Do not blanket-index foreign keys](do-not-blanket-index-foreign-keys.md).

## Which index is accepted as protection?

If you do decide on an index, its column structure has to be right. The post of
2023-03-27 tests this on a three-column foreign key (`ID1, ID2, ID3`) in seven
scenarios:

| Index definition | Protection effective? |
|---|---|
| no index | no |
| `(ID1)` — incomplete | no |
| `(ID1, ID2, ID3)` — complete | **yes** |
| `(ID3, ID1, ID2)` — complete, different order | **yes** |
| `(Name, ID3, ID1, ID2)` — extra column in front | no |
| `(ID1, Name, ID3, ID2)` — extra column in between | no |
| `(ID3, ID1, ID2, Name)` — extra column behind | **yes** |

**Rule:** an index is only accepted as protection for a foreign key if it
contains *all* constraint columns as its *leading* columns. Their order among
themselves is irrelevant; additional columns are only allowed *behind* the
constraint columns.

> Practical consequence: a multi-column index that happens to contain all foreign
> key columns does **not** protect the constraint if a foreign column sits in
> front of them or in between. That is an easily overlooked trap when reordering
> index columns.

## Relationships

- Role 3 of the four roles in [Indexing](indexing.md).
- [Index usage monitoring](index-usage-monitoring.md) does **not** record this usage, because it goes
  through recursive SQL — the role has to be ruled out separately.
- The decision about it: [Do not blanket-index foreign keys](do-not-blanket-index-foreign-keys.md).
- The general case of self-inflicted blocking: [Blocking locks](blocking-locks.md).

## Open questions

- Tested are 11.2, 12.1 and 19.3. How do 21c and 23ai behave?
- How does the column structure rule apply to partitioned or local indexes? The
  source only tests non-partitioned tables.

## Sources

- [Blog series on indexing](../sources/blog-indexing.md)
