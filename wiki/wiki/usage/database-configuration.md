---
title: Database configuration
type: entity
subtype: component
status: draft
tags: [panorama, menu, configuration]
created: 2026-10-05
updated: 2026-10-05
sources: [rammpeter.github.io.md, rammpeter.github.io/Oracle_performance_analysis_with_Panorama.html, rammpeter.github.io/panorama_content_generated.html]
---

# Database configuration

The submenu "DBA general" / "Database configuration" of [Panorama](panorama.md): how the
analysed database is set up — parameters, limits, options, services.

## The entries

([Panorama's website on GitHub Pages](../sources/rammpeter-github-io.md), menu overview.)

| Entry | Purpose as stated | See |
|---|---|---|
| Init-Parameter | Init-parameters of the instance(s) | below |
| Resource limits | From `gv$Resource_Limit` | |
| Optimizer hints | The optimizer hints this database supports | [Optimizer hints](optimizer-hints.md) |
| DB options | From `V$Option` | |
| TNS services | From `DBA_Services` | |
| Statistics level | System defaults from `gv$Statistics_Level` | |
| Diagnostic paths | Info and paths from `gv$Diag_Info` | [Optimizer diagnostics](optimizer-diagnostics.md) |
| Database properties | From `Database_Properties` | |
| Active SQL traces | Activation rules for SQL traces, and tracing sessions | [SQL trace](sql-trace.md) |
| DB vault configuration / DB vault realms | Configuration of DB vault realms | |

## Init parameters

(Usage guide 4.1.) The one tip the guide gives: **filter the column "Default" to
`FALSE`** — that leaves exactly the parameters that were set explicitly. This is
the quick way to see how a database deviates from Oracle's defaults.

Parameters that other pages of this wiki treat as decisive:

- `cursor_sharing` → [cursor_sharing = FORCE is no substitute for prepared statements](cursor-sharing-force-is-no-substitute.md)
- the SGA and shared pool sizes → [SGA memory management](sga-memory-management.md)
- the result cache settings → [Result cache](result-cache.md)
- `control_management_pack_access` → [Management pack licensing](management-pack-licensing.md)

## Related checks the guide files under configuration

Chapter 4 of the guide ("Evaluation of configuration and operation of the DB
system") continues with entries that sit elsewhere in the menu:

- memory configuration → [SGA memory management](sga-memory-management.md)
- dimensioning of the redo logs → [Redo logs](redo-logs.md)
- load and performance of the I/O system: the top-level menu "I/O analysis",
  which "contains several historic characteristics, throughput and time related
  values"; no page yet
- the audit trail → [Audit trail](audit-trail.md)

## Contradiction

The guide calls the entry "DBA General" / "Oracle Parameter". The generated menu
overview of the same date has "DBA general" / "Database configuration" /
"Init-Parameter". The generated one is taken as current; the guide's wording is
probably older.

## Relationships

- Listed in [Panorama menu overview](panorama-menu-overview.md).
- Parameter *history* is recorded in AWR (`DBA_Hist_Parameter`), and by
  [Panorama Sampler](panorama-sampler.md).

## Open questions

- Only the init parameters are described beyond one line; the other nine entries
  rest on their menu text alone.
- Whether the parameter view shows the history of changes or only the current
  values is not stated.

## Sources

- [Panorama's website on GitHub Pages](../sources/rammpeter-github-io.md)
