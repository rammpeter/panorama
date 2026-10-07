---
title: Analysis workflows in Panorama
type: concept
status: draft
tags: [panorama, workflow, core]
created: 2026-10-05
updated: 2026-10-05
sources: [rammpeter.github.io.md, rammpeter.github.io/]
---

# Analysis workflows in Panorama

How an analysis with [Panorama](panorama.md) is laid out: two ways of looking, three things
to look at, and one way of driving the interface that is the same everywhere.

## Two ways, three pillars

([Panorama's website on GitHub Pages](../sources/rammpeter-github-io.md), usage guide, chapter 2.)

**Two ways of analysis:**

- the **current state**, from internal system views (`V$`, dictionary views)
- **retrospectively**, for a period in the past, from recorded data — regularly
  [AWR](awr.md), which needs the Enterprise Edition with the Diagnostics Pack, or
  alternatively [Panorama Sampler](panorama-sampler.md), which needs neither

**Three pillars:**

| Pillar | Current | Retrospective |
|---|---|---|
| **DB sessions** | [Session list](session-list.md); wait state in [Session waits](session-waits.md); locks in [Blocking locks](blocking-locks.md) | [ASH](ash.md) through [Session waits](session-waits.md); locks from ASH or from the sampler |
| **SQL statements** | [SQL area](sql-area.md), from the SGA | [SQL area](sql-area.md), from AWR; single executions in [SQL Monitor](sql-monitor.md) |
| **DB objects** | [Describe object](describe-object.md); [Segment statistics](segment-statistics.md); [DB cache usage](db-cache-usage.md) | [Segment statistics](segment-statistics.md) per AWR snapshot; [DB cache usage](db-cache-usage.md) from the sampler |

> Conclusion: the pillars are entry points, not separate tools. Each view links
> into the others — a session to its SQL, a SQL to the objects in its plan, an
> object to the SQL that touches it — so an analysis may start at whichever
> pillar the symptom points to.

Around this core the guide places four further tasks:

- scanning the whole system for antipatterns → [Dragnet Investigation](dragnet.md)
- checking configuration and operation → [Database configuration](database-configuration.md),
  [SGA memory management](sga-memory-management.md), [Redo logs](redo-logs.md), [Audit trail](audit-trail.md)
- influencing execution plans → [SQL plan management](sql-plan-management.md),
  [SQL Translation Framework](sql-translation-framework.md)
- using storage well → [Storage reorganisation](storage-reorganisation.md), [Index compression](index-compression.md),
  [Function-based indexes](function-based-indexes.md), [Index usage monitoring](index-usage-monitoring.md)

The complete list of entry points is [Panorama menu overview](panorama-menu-overview.md).

## How the interface is driven

([Panorama's website on GitHub Pages](../sources/rammpeter-github-io.md), usage guide, section 1.2.)

**Globally**

- Mouse-over hints carry contextual information almost everywhere.
- Details of a displayed value are opened by clicking its hyperlink.
- **A workflow grows downwards.** Each further step is rendered *below* the
  previous content of the page.
- **Going back cuts off what follows.** Clicking a link in an earlier step
  deletes the block underneath and replaces it with the result of the new click.

The landing page adds the consequence: Panorama renders one single web page by
AJAX calls, so **the browser's back button does not return to earlier content**.
Why the page is built this way is described in
[Controllers, routing and rendering in Panorama](../development/panorama-request-and-rendering.md).

**Tables**

- Clicking a column header sorts; sorting by several columns is done by sorting
  the columns one after another.
- The **context menu** (right mouse button) offers, independent of the column:
  a search-filter row with a filter per displayed column; export to Excel as a
  CSV file; switching the line height between one line and the full field
  content.
- And for the column under the pointer: the column sum and the number of
  distinct values; the field content in a popup (for copy and paste); showing
  or hiding the column in a **diagram** — only if the rows have a time
  reference.
- Two icons in the table header: **show the search filter** (left) and **pin the
  table** (right), which protects it from being overwritten when its parent is
  reloaded.

The screenshot `table.png` (viewed) shows the context menu on a redo log history
with its entries: "Sort by this column", "Show search filter", "Export grid in
csv-file", "Sums of all rows of this column", "Show content of table cell",
"Line height for single line only", "Show column in diagram", "Remove all graphs
from diagram", "Switch column sort method to bubble sort".

> Conclusion: pinning is the answer to the rule that going back cuts off what
> follows. To compare two drill-downs from the same parent, pin the first before
> opening the second.

## Relationships

- The tool: [Panorama](panorama.md); the stance behind the system-wide scan:
  [Proactive performance tuning](proactive-performance-tuning.md).
- Restoring a reached state later or passing it on: "Execute with given
  parameters", see [Panorama](panorama.md).
- Needed grants: [Privileges for Panorama](panorama-privileges.md).

## Open questions

- The guide is marked as under construction; chapters 5 and 7 are largely empty
  headings. The procedures it would describe there are covered in this wiki from
  the blog and the talks instead, not from the guide.
- The last context menu entry, "Switch column sort method to bubble sort", is
  not explained in any source.

## Sources

- [Panorama's website on GitHub Pages](../sources/rammpeter-github-io.md)
