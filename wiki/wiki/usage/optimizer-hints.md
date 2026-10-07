---
title: Optimizer hints
type: concept
status: draft
tags: [execution-plan, optimizer, oracle]
created: 2026-10-01
updated: 2026-10-02
sources: [blog.md, posts/]
---

# Optimizer hints

> "What does the database really do with your optimizer hints in SQL statements?"
> — [Blog series on execution plans and the optimizer](../sources/blog-execution-plans.md), 2023-12-07

A hint in the SQL text is a request, not an instruction. Whether the database
followed it, ignored it or did not even understand it was long impossible to
tell. **Since Oracle 19c** it is in the `hint_usage` section of the `OTHER_XML`
column — in `V$SQL_PLAN`, `DBA_HIST_SQL_PLAN` and `PLAN_TABLE`, in each case
correlated with the plan line.

## Structure of `hint_usage`

```
<hint_usage>
  <q>              one block per query block
    <n>            the name of the query block
    <h>            hint bound directly to the query block
    <m>            scope: query block   (marked "unsure" by the author)
    <s>            scope: statement
    <t>            scope: join          (marked "unsure" by the author)
  <s>              one block per statement
    <h>            hint bound directly to the statement
```

Inside a scope: `<f>` the alias of the object (for object-related scope), `<h>`
the hint data — multiple occurrences possible. Inside `<h>`: `<x>` the hint
syntax, `<r>` optionally the reason for a problem.

## The attributes – the actual value

**Origin** (attribute `o`):

| Value | Meaning |
|---|---|
| `EM` | the hint comes from the author of the SQL |
| `OU` | Oracle set it internally itself |
| `SP` / `SR` | it comes from a SQL profile |
| `SH` | belongs to the MMON stats advisor (SQL tagged `/* SQL Analyze(n,m) */`) |

**State** (attribute `st`), with the letter used in `DBMS_XPLAN`'s note in
brackets:

| Value | Meaning |
|---|---|
| `EU` | unused ("U") |
| `NU` | unused ("U") |
| `PE` | parsing syntax error ("E") |
| `UR` | unresolved ("N") |

A hint without an `st` attribute was applied.

## Two routes in

**Readably formatted:** `DBMS_XPLAN.DISPLAY*` with the format tag
`+HINT_REPORT` prints the hint usage along with the query block names. The report
summarises first and then lists per plan line — in the source's example:

```
Hint Report (identified by operation id / Query Block Name / Object Alias):
Total hints for statement: 5 (U - Unused (1), E - Syntax error (1))

  1 -  OUTER
         E -  NONSENS
         -  QB_NAME(Outer)
  4 -  OUTER / C@OUTER
         -  FULL(c)
```

A hint without a letter was applied; `E` marks the syntax error (`NONSENS`) here,
`U` an unused one.

**Searchable system-wide:** the post supplies two SQL statements using
`XMLTABLE` against `GV$SQL_PLAN.OTHER_XML` — one that counts all occurring
tag/attribute combinations, and one that specifically lists **all unused,
unresolved or erroneous hints** of expensive SQL (filtered via `st="EU"`,
`"NU"`, `"PE"`, `"UR"`).

The measurement on a larger OLTP system yields a revealing distribution: around
5,700 occurrences with `EM,PE` — hints written by the author with a **syntax
error** — and around 6,400 with `NU` — written but not used.

> Conclusion: wrongly written and ineffective hints are not a marginal
> phenomenon. They never get noticed, because an erroneous hint does not disturb
> execution — it is silently discarded.

## In Panorama

The hints sit on the respective plan line. If a hint is erroneous or unused, the
object of the plan line gets a **pink background**. Hints and the query block
name can be shown as separate columns via the context menu; otherwise they appear
in the tooltip of the object column.

## Relationships

- A hint can also be applied without changing the SQL →
  [SQL plan management](sql-plan-management.md) (SQL patch).
- An example of a deliberately placed hint: [VIEW PUSHED PREDICATE](view-pushed-predicate.md).
- Searching for index names in hints is part of the pre-drop check →
  [Index usage monitoring](index-usage-monitoring.md).
- The same `OTHER_XML` also explains the absence of parallel processing →
  [Parallel execution](parallel-execution.md).

## Open questions

- The meaning of `<m>` and `<t>` is **unresolved** — the author marks both
  himself with "(unsure)".
- How do `EU` and `NU` differ, both meaning "unused"?
- Is there official Oracle documentation of the `hint_usage` structure? The post
  rests on the author's own observation and on prior work by Franck Pachot and
  Rene Nyffenegger.

## Sources

- [Blog series on execution plans and the optimizer](../sources/blog-execution-plans.md)
