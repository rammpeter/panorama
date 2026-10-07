---
title: SQL area
type: entity
subtype: component
status: draft
tags: [panorama, menu, sql]
created: 2026-10-05
updated: 2026-10-05
sources: [rammpeter.github.io.md, rammpeter.github.io/Oracle_performance_analysis_with_Panorama.html, rammpeter.github.io/panorama_content_generated.html]
---

# SQL area

The submenu "SGA/PGA-Details" / "SQL-Area" of [Panorama](panorama.md): finding problematic
SQL statements — those still in memory and those recorded in [AWR](awr.md) — and the
detail view every SQL analysis ends in.

## The entries

([Panorama's website on GitHub Pages](../sources/rammpeter-github-io.md), menu overview.)

| Entry | Purpose as stated |
|---|---|
| Current SQLs (SQL-ID) | Current SQL in the SGA at level SQL-ID, "cumulated across child-cursors" |
| Current SQLs (SQL-ID / child-no.) | Current SQL in the SGA at level SQL-ID and child number |
| Historic SQLs | Historic SQL from `DBA_Hist_SQLStat` |
| SQL-Monitor reports | Recorded reports from `gv$SQL_Monitor` and `DBA_HIST_Reports` → [SQL Monitor](sql-monitor.md) |
| Long operations | Long running operations from `GV$Session_LongOps` → [Long operations](long-operations.md) (in the list since the regeneration of 2026-10-05) |
| SQL-Area day comparison | Comparison of SQL statements from two different days |

## Current SQL from the SGA

(Usage guide 2.2.1.) Both entries start with a choice of **filters and a sorting
criterion**. The two levels differ in what a result row is:

- **SQL-ID:** one row per unique SQL.
- **SQL-ID, child number:** one row per separately parsed child cursor.

A click on the SQL-ID opens the detail view. Entering at the SQL-ID level, **the
execution plan is shown only if it is unique** for that SQL-ID. If several child
cursors exist, they are listed as a table instead, each leading to the detail
view of that concrete child cursor — which then contains its plan.

> Conclusion: this is the interface's way of not showing "the" plan where there
> is none. Several child cursors with different plans are the starting point of
> the analyses in [Execution plans](execution-plans.md) and
> [Bind variables and cursor sharing](bind-variables-and-cursor-sharing.md).

## Historic SQL from AWR

(Usage guide 2.2.2.) Entered with a **time period, a sort order and optional
filters** — or by cross reference, for instance from an ASH evaluation
([Session waits](session-waits.md)). A click on the SQL-ID shows the detail view with the values
*between the AWR snapshots that cover the period*. Buttons in the footer bar lead
to further details of that SQL.

Two of those buttons are named in the guide's chapter on plan control: "Complete
history", which lists the periods in which the SQL ran and with which plan, and
the generators for "SQL Plan Baseline", "SQL patch" and "SQL translation"
→ [SQL plan management](sql-plan-management.md), [SQL Translation Framework](sql-translation-framework.md).

The detail view shows **in signal red** if a SQL plan baseline, a SQL profile, a
SQL patch or a SQL translation exists for the statement.

## Licence

"Historic SQLs" and the day comparison read `DBA_HIST_…` and need the
Diagnostics Pack or [Panorama Sampler](panorama-sampler.md); the SQL Monitor reports need the Tuning
Pack ([Management pack licensing](management-pack-licensing.md)). The two "Current" entries read the SGA and
need neither.

## Relationships

- Listed in [Panorama menu overview](panorama-menu-overview.md); the second pillar in
  [Analysis workflows in Panorama](panorama-analysis-workflows.md).
- What a plan in the detail view tells: [Execution plans](execution-plans.md),
  [Index access paths](index-access-paths.md), [Optimizer hints](optimizer-hints.md).
- System-wide search for SQL with literals: [Dragnet Investigation](dragnet.md),
  [Bind variables and cursor sharing](bind-variables-and-cursor-sharing.md).

## Open questions

- "SQL-Area day comparison" is described only by its one-line purpose.
- The sort criteria and filters of the entry dialogs are not listed in the
  source.

## Sources

- [Panorama's website on GitHub Pages](../sources/rammpeter-github-io.md)
