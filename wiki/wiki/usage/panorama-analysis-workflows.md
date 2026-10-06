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

How an analysis with [[panorama]] is laid out: two ways of looking, three things
to look at, and one way of driving the interface that is the same everywhere.

## Two ways, three pillars

([[rammpeter-github-io]], usage guide, chapter 2.)

**Two ways of analysis:**

- the **current state**, from internal system views (`V$`, dictionary views)
- **retrospectively**, for a period in the past, from recorded data — regularly
  [[awr]], which needs the Enterprise Edition with the Diagnostics Pack, or
  alternatively [[panorama-sampler]], which needs neither

**Three pillars:**

| Pillar | Current | Retrospective |
|---|---|---|
| **DB sessions** | [[session-list]]; wait state in [[session-waits]]; locks in [[blocking-locks]] | [[ash]] through [[session-waits]]; locks from ASH or from the sampler |
| **SQL statements** | [[sql-area]], from the SGA | [[sql-area]], from AWR; single executions in [[sql-monitor]] |
| **DB objects** | [[describe-object]]; [[segment-statistics]]; [[db-cache-usage]] | [[segment-statistics]] per AWR snapshot; [[db-cache-usage]] from the sampler |

> Conclusion: the pillars are entry points, not separate tools. Each view links
> into the others — a session to its SQL, a SQL to the objects in its plan, an
> object to the SQL that touches it — so an analysis may start at whichever
> pillar the symptom points to.

Around this core the guide places four further tasks:

- scanning the whole system for antipatterns → [[dragnet]]
- checking configuration and operation → [[database-configuration]],
  [[sga-memory-management]], [[redo-logs]], [[audit-trail]]
- influencing execution plans → [[sql-plan-management]],
  [[sql-translation-framework]]
- using storage well → [[storage-reorganisation]], [[index-compression]],
  [[function-based-indexes]], [[index-usage-monitoring]]

The complete list of entry points is [[panorama-menu-overview]].

## How the interface is driven

([[rammpeter-github-io]], usage guide, section 1.2.)

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
[[panorama-request-and-rendering]].

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

- The tool: [[panorama]]; the stance behind the system-wide scan:
  [[proactive-performance-tuning]].
- Restoring a reached state later or passing it on: "Execute with given
  parameters", see [[panorama]].
- Needed grants: [[panorama-privileges]].

## Open questions

- The guide is marked as under construction; chapters 5 and 7 are largely empty
  headings. The procedures it would describe there are covered in this wiki from
  the blog and the talks instead, not from the guide.
- The last context menu entry, "Switch column sort method to bubble sort", is
  not explained in any source.

## Sources

- [[rammpeter-github-io]]
