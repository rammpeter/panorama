---
title: Declare DETERMINISTIC deliberately – but not with function based indexes
type: decision
decision_status: adopted
status: draft
tags: [plsql, optimizer, index, oracle]
created: 2026-10-01
updated: 2026-10-02
sources: [blog.md, posts/]
---

# Declare DETERMINISTIC deliberately – but not with function based indexes

**Status: adopted.** A function may be labelled `DETERMINISTIC` even if strictly
speaking it is not — **except** when it carries a function based index. There the
same declaration leads to data errors.

## Why this page exists

Two blog posts deal with the same declaration and arrive at opposite
recommendations. Both are right; the difference lies in the context of use and is
easy to overlook.

| Post | Statement |
|---|---|
| 2026-01-14 ([Blog series on caching and PL/SQL](../sources/blog-caching-and-plsql.md)) | Functions reading master data **may** be declared `DETERMINISTIC` |
| 2023-08-15 ([Blog series on locks and serialisation](../sources/blog-locks.md)) | Precisely that ends in `ORA-08102: index key not found` |

## The recommendation – and its rationale

> "The reuse of function results is limited to a single SQL execution. It might
> therefore also make sense to label functions as DETERMINISTIC that are not
> actually deterministic."
> — [Blog series on caching and PL/SQL](../sources/blog-caching-and-plsql.md), 2026-01-14

The argument is precise: a function reading values from master data tables is
**not** deterministic, because the table contents can change. But:

- The caching only extends across **one** SQL execution.
- Within a single SQL execution you are practically **not interested** in a
  change to the table contents.

So you can label the function that way anyway and thereby ensure it is called
"much less frequently than otherwise". The scale of the gain is shown in
[DETERMINISTIC](deterministic.md): one million calls against one.

## The boundary – and why it is hard

A **function based index** technically requires a deterministic function. Here
the assumption becomes a persisted fact: the index key is **stored** with the
return value of that moment.

If the data read changes, the index points at a value the function no longer
returns. The proof in [Blog series on locks and serialisation](../sources/blog-locks.md) (2023-08-15) takes four statements:

```sql
INSERT INTO Master (ID, Company_ID) VALUES (8, 7);
INSERT INTO Detail (Master_ID, Value) VALUES (8, 7);
UPDATE Master SET Company_ID = 6 WHERE ID = 8;   -- contradicts DETERMINISTIC
UPDATE Detail SET Value = 9 WHERE Master_ID = 8; -- ORA-08102
```

> **The dividing line:** in ordinary use within SQL, `DETERMINISTIC` is an
> optimisation assurance whose validity is only needed for the duration of *one*
> execution. With a function based index it is an assurance across the entire
> lifetime of the index — and a table-reading function cannot keep that.

## Open despite the decision (implementation risks)

- **The boundary cannot be enforced.** Nothing prevents someone later putting a
  function based index on a function that was deliberately declared wrongly. The
  declaration does not carry its reason with it — a comment on the function is
  the least you should do.
- **Which other features rely on it?** The sources deal with function based
  indexes and ordinary SQL use. Whether virtual columns, materialized views or
  partitioning over function expressions need the same hard assurance is not
  evidenced — when in doubt the same caution applies.
- **"Practically not interested" is a domain assumption.** For a query running
  for hours it may be wrong.
- **It remains a false statement.** It stands or falls with the database's
  assurance that reuse really is limited to one execution. If Oracle changes
  that, the assessment changes.

## Provenance

- Recommendation from the post of **2026-01-14** ("Check user-defined PL/SQL
  functions for missing DETERMINISTIC flag").
- Counter-evidence from the post of **2023-08-15** ("Ensure uniqueness across
  table boundaries"), where `DETERMINISTIC` is characterised as *"can simply be
  declared by a keyword"* and demonstrated to be unsuitable for function based
  indexes.
- Bringing the two statements together into one rule is a **synthesis of this
  wiki**, not a statement by the author — he treats the cases separately and does
  not draw the connection.
- Ingested into the wiki on 2026-10-01.

## Relationships

- Mechanics and measurement: [DETERMINISTIC](deterministic.md)
- The failure case in detail: [Cross-table uniqueness](cross-table-uniqueness.md)
- A function based index additionally needs statistics:
  [Extended statistics](extended-statistics.md)

## Sources

- [Blog series on caching and PL/SQL](../sources/blog-caching-and-plsql.md)
- [Blog series on locks and serialisation](../sources/blog-locks.md)
