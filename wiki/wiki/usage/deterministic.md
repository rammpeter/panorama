---
title: DETERMINISTIC
type: concept
status: draft
tags: [plsql, optimizer, oracle]
created: 2026-10-01
updated: 2026-10-04
sources: [blog.md, posts/, speakerdeck.md, speakerdeck/]
---

# DETERMINISTIC

A keyword in the function declaration by which you tell the optimizer that the
result is stable for the same parameters. The database **does not check that** —
it believes it.

## What it achieves

([Blog series on caching and PL/SQL](../sources/blog-caching-and-plsql.md), 2026-01-14) If the SQL engine knows a function is
deterministic, it can cache its results across repeated calls.

The author's experiment, measured with a counter in a package variable:

A table `MyTab` with **1 million** rows; a package function computes a value used
as a filter criterion:

```sql
SELECT * FROM MyTab WHERE ID = MyPack.MyFunc;
```

| Declaration | Function calls |
|---|---|
| without `DETERMINISTIC` | **1,000,000** |
| with `DETERMINISTIC` | **1** |

> The function call has **no relation to any row value**. It is nevertheless
> executed per row — because the database cannot know that the same thing comes
> out every time.

## The limit of the reuse

Decisive for understanding — and for the recommendation that follows from it:

> **The reuse of function results is limited to a single SQL execution.**

From that the author derives a deliberately unorthodox recommendation — to label
functions `DETERMINISTIC` that are not. On that and on its boundary:
**[Declare DETERMINISTIC deliberately – but not with function based indexes](declaring-deterministic-deliberately.md)**.

## Finding candidates

The post supplies a PL/SQL block that searches the database for long-running SQL
using **non**-deterministic user-defined functions. The procedure:

1. Collect all user-defined functions not declared deterministic, indexed by name
   and by `Owner.Name`.
2. Tokenise the SQL texts from `GV$SQLAREA` (and the AWR history) using a list of
   delimiter characters and check every token against that list — a small parser
   in PL/SQL.
3. On a match, include any following parameter list.
4. Check whether the function name appears in the **access or filter predicates**
   of the plan, and output the plan line in question.
5. Output the result as one JSON line per match via `DBMS_OUTPUT`.

> Step 4 is the actual value: a function in a predicate is potentially evaluated
> per row. That is exactly where the case from the experiment sits.

The author is clear about what the result is: *"It's up to you to evaluate and
decide if this functions could be tagged as DETERMINISTIC or not."* A
pre-selection, not a recommendation per function.

## Relationships

- The position on the declaration:
  [Declare DETERMINISTIC deliberately – but not with function based indexes](declaring-deterministic-deliberately.md).
- The trap with a function based index: [Cross-table uniqueness](cross-table-uniqueness.md).
- A function based index additionally needs statistics, otherwise it remains
  ineffective → [Extended statistics](extended-statistics.md).
- Access versus filter predicate as an analysis criterion: also in
  [Index access paths](index-access-paths.md) and [Partition pruning](partition-pruning.md).
- The related caching topic: [Master data caching](master-data-caching.md), [Result cache](result-cache.md).
- Why index maintenance breaks on a function that is not really deterministic:
  [Function-based indexes](function-based-indexes.md).

## Open questions

- Under exactly what conditions does the caching within one SQL execution take
  effect? The experiment shows the extreme case, not the rule.
- How does it behave for functions **with** parameters that vary per row — is
  caching then done per parameter value?

## Sources

- [Blog series on caching and PL/SQL](../sources/blog-caching-and-plsql.md)
- [Talks on indexes](../sources/talks-indexes.md)
