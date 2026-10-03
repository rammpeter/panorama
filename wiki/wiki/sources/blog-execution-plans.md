---
title: Blog series on execution plans and the optimizer
type: source
status: maintained
tags: [execution-plan, optimizer, oracle]
created: 2026-10-01
updated: 2026-10-02
sources: [blog.md, posts/]
---

# Blog series on execution plans and the optimizer

Nine posts from [[rammpeter-blog]] between 2016 and 2026 on the question of how
to understand an execution plan, keep it stable and, if necessary, force it —
without touching the application's SQL.

## The posts

| Date | Title | Focus |
|---|---|---|
| 2016-03-20 | Fix changed execution plan with SQL plan baseline | [[sql-plan-management]] |
| 2016-04-27 | How to identify and evaluate SQL with different execution plans | [[execution-plans]] |
| 2018-01-14 | Handle SQL patches for Oracle-DB | [[sql-plan-management]], [[create-sql-patches-by-sql-text]] |
| 2023-06-07 | How to enforce the optimizer to do group operations at the most inner level | [[view-pushed-predicate]] |
| 2023-12-07 | How to evaluate the "hint_usage" section of column OTHER_XML | [[optimizer-hints]] |
| 2023-12-20 | Get the benefits of Access_Predicates and Filter_Predicates in AWR | [[execution-plans]] |
| 2025-08-07 | New SQL Diagnostic Report in rel. 19.28 | [[optimizer-diagnostics]] |
| 2026-03-31 | Create trace file for optimizer parse (event 10053) | [[optimizer-diagnostics]] |
| 2026-06-29 | Retrieving extended statistics in execution plan for a specific SQL only | [[optimizer-diagnostics]] |

## Key points

**Changing plans are the real risk.** Not the bad plan but the *unpredictably
changing* one makes runtimes impossible to budget for. Panorama offers five ways
to find them — from the "P." column in the SQL area list to the system-wide scan
in [[dragnet]] (2016-04-27) → [[execution-plans]].

**A good plan can be retrieved from the AWR history.** A historical plan is
loaded into a SQL plan baseline via a SQL tuning set and thereby pinned. The
author explicitly calls the solution **temporary only**: if the SQL is modified,
it loses its binding to the baseline (2016-03-20)
→ [[sql-plan-management]].

**SQL patches are the licence-free lever.** Unlike baselines and profiles they
need no additional licence and also work with Standard Edition. That makes them
the means of choice for slipping an optimizer hint into a SQL without changing
the application (2018-01-14, confirmed 2026-06-29)
→ [[sql-plan-management]].

**Since 19c the database reveals what it did with the hints.** The `hint_usage`
section in `OTHER_XML` says, per plan line, whether a hint was applied, ignored,
unresolved or syntactically wrong — and whether it came from the SQL's author or
from Oracle itself (2023-12-07) → [[optimizer-hints]].

**An old AWR plan blocks the new predicate columns.** From 19.19 Oracle finally
populates `Access_Predicates` and `Filter_Predicates` in `DBA_HIST_SQL_PLAN`.
Plans stored before that, however, stay empty **forever** as long as their SQL
keeps appearing in AWR snapshots — independently of the retention period
(2023-12-20) → [[execution-plans]].

**Extended plan statistics without changing the application.** Instead of writing
`GATHER_PLAN_STATISTICS` into the source code, you inject the hint via a SQL
patch, measure, and drop the patch again (2026-06-29)
→ [[optimizer-diagnostics]].

**GROUP BY belongs on the inside.** The optimizer tends to pull grouping outwards
and thus execute it on larger sets than necessary. A `NO_MERGE` hint forces the
`VIEW_PUSHED_PREDICATE` operation instead — in the measured example 38 % faster
than the best alternative (2023-06-07) → [[view-pushed-predicate]].

## Impact on the wiki

New: [[execution-plans]], [[sql-plan-management]], [[optimizer-hints]],
[[optimizer-diagnostics]], [[view-pushed-predicate]] and the decision
[[create-sql-patches-by-sql-text]].

Extended: [[management-pack-licensing]] — this series supplies the most concrete
statements so far about what stays licence-free.

## Notes on the evidence

**A licence statement checked empirically.** For the SQL Diagnostic Report
(2025-08-07) the author does not settle for the documentation but verifies on a
fresh 23.9 database, via `DBA_FEATURE_USAGE_STATISTICS`, whether using it marks a
licensable feature. Result: only "Oracle Utility Metadata API". At the same time
he notes that the supporting MOS note (Doc ID 1509192.1) was last updated in
2022 — so the statement is evidenced, but not timeless.

**Two uncertainties are stated explicitly in the text.** When interpreting the
`hint_usage` structure the author himself marks two tags with "(unsure)" —
`<m>` (scope: query block) and `<t>` (scope: join). That is carried over as such
into [[optimizer-hints]], not smoothed away.

**Prior work by others is named.** The baseline solution goes back to Filipe
Martins and rmoff, the interpretation of `hint_usage` to Franck Pachot and Rene
Nyffenegger, the SQL patch post thanks Jonathan Lewis, the licence research
Claudia Hüffer.

## Source files

`raw/posts/09-*`, `12-*`, `31-*`, `51-*`, `54-*`, `56-*`, `67-*`, `70-*`, `72-*`
