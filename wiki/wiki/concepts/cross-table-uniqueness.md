---
title: Cross-table uniqueness
type: concept
status: draft
tags: [locks, plsql, index, oracle]
created: 2026-10-01
updated: 2026-10-02
sources: [blog.md, posts/]
---

# Cross-table uniqueness

A constraint Oracle does not offer declaratively: a column combination is to be
unique, where part of the combination comes from a **referenced table**. The road
there leads through triggers — and through serialisation, which has its price.

## The task

([[blog-locks]], 2023-08-15) Two tables: `MASTER` is referenced by `DETAIL`. The
combination of `DETAIL.VALUE` and `MASTER.COMPANY_ID` is to be unique. All
columns except the primary keys may change.

## The obvious route fails

The first thought is usually a function based index over a function that fetches
the second value from the referenced table:

```sql
CREATE OR REPLACE FUNCTION Get_Company_ID(p_Master_ID IN NUMBER) RETURN NUMBER DETERMINISTIC IS ...
CREATE UNIQUE INDEX IX_Value_Company_ID_Unique ON Detail(Value, Get_Company_ID(Master_ID));
```

A function based index requires a **deterministic** function. And
`DETERMINISTIC`, as the author drily observes, "can simply be declared by a
keyword" — the database does not check it.

> A function whose return value depends on table contents is as a rule **not**
> deterministic.

The proof in four statements: after an `UPDATE` of the column read in `MASTER`,
the index holds a value the function no longer returns. The next change in
`DETAIL` fails with

```
ORA-08102: index key not found, obj# 79600, file 12, block 1931 (2)
```

**The source's conclusion:** function based indexes are unsuitable for this
requirement as soon as the data read can change. On the more general question see
[[deterministic]] and [[declaring-deterministic-deliberately]].

## The workable route: two compound triggers

One `COMPOUND TRIGGER` each with an `AFTER STATEMENT` section:

- on `DETAIL` for `INSERT OR UPDATE OF Master_ID, Value`
- on `MASTER` for `UPDATE OF Company_ID`

The check runs only **after** the statement. If it fires,
`RAISE_APPLICATION_ERROR` aborts the running DML. The error message names the
violating values — with bulk DML the decisive hint as to which records are
guilty.

### Why serialisation is necessary

The check has to see the **complete** contents of both tables — including changes
from competing, not yet committed transactions. Oracle cannot read uncommitted
data. So the only option left is to serialise the transactions:

```sql
LOCK TABLE Master IN EXCLUSIVE MODE;  -- until all competing transactions have finished
```

If several sessions provoke a violation simultaneously, the session with the
**last commit** receives the error.

**The price is stated explicitly in the text:** *"Global serialization of DML on
a table may significantly downgrade performance."* And the author records that he
has found no better solution:

> "Unfortunately, I have not yet found a waterproof solution with that trigger
> approach without global serialization, at least for insert DML."

## The check query, optimised in four stages

The most instructive part of the post — from the brute force approach to the lean
variant, with an execution plan for each:

1. **Brute force.** Grouping over the join of *both complete tables* on every
   DML. It works; it does not scale.
2. **Restrict to the values touched.** An `AFTER EACH ROW` section remembers the
   affected `VALUE`s in an associative array; only those are checked, via an
   index on `DETAIL(Value)`.
3. **Pre-group.** The access to `MASTER` is only needed **once** per combination
   of `VALUE` and `Master_ID`, not per `DETAIL` record. An inline view with
   `NO_MERGE` groups the `Master_ID`s first — the same pattern as in
   [[view-pushed-predicate]].
4. **Avoid table access entirely.** If the indexes are extended by the columns
   read (`DETAIL(Value, Master_ID)` and `MASTER(ID, Company_ID)`), the check
   query only accesses indexes.

## Relationships

- One of the four roles in [[indexing]] is "guarantee uniqueness" — this is the
  case where it is **not** achievable declaratively.
- The deliberately induced serialisation is the counterpart to
  [[blocking-locks]], where it is the problem.
- The `DETERMINISTIC` trap in detail: [[deterministic]], and the rule derived
  from it: [[declaring-deterministic-deliberately]].
- The optimisation of the check query uses [[view-pushed-predicate]].

## Open questions

- **Unresolved:** a waterproof solution without global serialisation, at least
  for insert DML. The author explicitly asks for suggestions.
- How expensive is the serialisation in numbers? The source warns but does not
  measure.
- Would a materialized view with `REFRESH ON COMMIT` and a unique constraint on
  it be an alternative? Not considered in the post.

## Sources

- [[blog-locks]]
