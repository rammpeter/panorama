---
title: Describe object
type: entity
subtype: component
status: draft
tags: [panorama, menu, objects]
created: 2026-10-05
updated: 2026-10-05
sources: [rammpeter.github.io.md, rammpeter.github.io/Oracle_performance_analysis_with_Panorama.html, rammpeter.github.io/images/describe_db_object.png]
---

# Describe object

The menu entry "Schema / Storage" / "Describe object" of [[panorama]]: structure
and current state of one database object — table, index, materialized view and
others — and the hub that most object-related views link to.

## Use

([[rammpeter-github-io]], usage guide 2.3.1; menu overview: "Describe database
object (table, index, materialized view ...)".)

- Shows the **structure and the current state** of a particular object.
- **Buttons in the footer line** dig into individual aspects of the object.
- The view is **linked from several other views** — wherever an object name
  appears, it is usually the target.

The screenshot `describe_db_object.png` is archived but was not viewed.

## Checking whether the statistics are realistic

(Usage guide 6.1.) The guide names realistic object statistics as **the first
prerequisite for good execution plans**, and this view as the place to check
them:

1. For tables and indexes, a click in the column **"Rows"** counts the *current*
   number of rows.
2. Compare it with the row count according to the last analysis.
3. On a gross discrepancy "with problematic effects on the execution of SQLs",
   gather again with `DBMS_STATS.GATHER_TABLE_STATS`.

Regular analysis should otherwise be ensured by the database's default scheduler
settings or by an analysis of your own.

> Conclusion: the check is deliberately manual and per object. It answers "is
> the optimizer working from a wrong picture of *this* table", the question that
> arises once a specific plan looks wrong — see [[execution-plans]] and
> [[optimizer-diagnostics]]. Where single-column statistics are right but the
> estimate is still wrong: [[extended-statistics]].

## Related object views

Described from other sources in this wiki, and belonging to the same object
context (whether each is a button of this view is not evidenced): the index list that puts usage state,
uniqueness, foreign key protection and partition exchange side by side
([[indexing]], [[index-usage-monitoring]]), and the compression suggestions
([[index-compression]], [[advanced-compression]]).

## Relationships

- Listed in [[panorama-menu-overview]]; the third pillar in
  [[panorama-analysis-workflows]].
- Load on an object rather than its structure: [[segment-statistics]],
  [[db-cache-usage]].
- Space below the high water mark: [[storage-reorganisation]].

## Open questions

- The buttons of the footer line are not enumerated in the source.
- Counting rows by a click is a full count on the live table; what it costs on
  very large tables, and whether Panorama limits or samples it, is not stated.

## Sources

- [[rammpeter-github-io]]
