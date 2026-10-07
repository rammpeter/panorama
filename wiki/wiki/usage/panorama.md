---
title: Panorama
type: entity
subtype: product
status: draft
tags: [core]
created: 2026-10-01
updated: 2026-10-05
sources: [blog.md, posts/, panorama-repository.md, speakerdeck.md, speakerdeck/, rammpeter.github.io.md, rammpeter.github.io/]
---

# Panorama

A web-based tool for performance analysis of Oracle databases: it connects to a
target database at runtime and presents its system views (`V$`/`GV$`, `DBA_*`,
`DBA_HIST_*`) as navigable evaluations.

## Summary

The author's own description ([Blog series on indexing](../sources/blog-indexing.md), 2019-12-27):

> "Panorama is the author's Swiss Army Knife, a freely usable tool for Oracle-DB
> performance analysis. It is based on read-only SQL-accessible information of
> the DB, including data from the AWR."

Four properties characterise the tool:

- **Read-only.** Panorama relies exclusively on information readable via SQL.
  Where it would intervene by changing something, it instead generates a snippet
  for you to execute yourself — for SQL plan baselines, SQL patches and SQL
  translations ([SQL plan management](sql-plan-management.md), [SQL Translation Framework](sql-translation-framework.md)).
- **Freely available**, as a JAR and as a Docker image →
  [Panorama operations](panorama-operations.md).
- **Licence-aware.** The licensing model is built into the workflow, not glued
  on → [Management pack licensing](management-pack-licensing.md).
- **Usable without the Diagnostics Pack**, via [Panorama Sampler](panorama-sampler.md) — whose data
  is evaluated *transparently in the same place* as real AWR/ASH.

## Recurring patterns of the interface

Evidenced again and again across the posts — they give the tool its actual
character:

- **Every cell is a link** that leads one level deeper: from the minute into the
  ASH records, from the session into its SQL, from the plan line into the wait
  events. Several posts describe an analysis purely as a sequence of clicks.
- **Every table becomes a chart**, via the context menu on a column.
- **Colour marks the conspicuous:** orange for the root session of a lock chain
  ([Blocking locks](blocking-locks.md)), orange for multiple plans ([Execution plans](execution-plans.md)), pink for
  an ineffective hint ([Optimizer hints](optimizer-hints.md)), a coloured background for missing
  extended statistics ([Extended statistics](extended-statistics.md)).
- **States are shareable.** Filter states you have reached can be copied to the
  clipboard as request parameters and restored later via "Spec. additions /
  Execute with given parameters" — to pass on to colleagues or for a later
  comparison ([Blog series on Panorama as a tool](../sources/blog-panorama-the-tool.md), 2016-11-16).
- **Warnings against misinterpretation.** If a SQL patch or a SQL translation
  exists for a SQL, that is shown in **every** detail view — "to explicitly
  prevent misinterpretation of execution plan".

## Functional domains

The complete menu, entry by entry, is in [Panorama menu overview](panorama-menu-overview.md)
([Panorama's website on GitHub Pages](../sources/rammpeter-github-io.md), generated from the source code on 2026-10-05). In
short:

| Menu | Content | See |
|---|---|---|
| "DBA general" | start page, dashboard, DB locks, redo logs, sessions, database configuration, user management, audit trail, server files, database triggers, DB links, scheduled jobs, feature usage, patch history | [Blocking locks](blocking-locks.md), [Redo logs](redo-logs.md), [Session list](session-list.md), [Database configuration](database-configuration.md), [Audit trail](audit-trail.md) |
| "Analyses / statistics" | session waits (incl. long-term trend), segment statistics, system events, statistics and metrics, time model, latches, mutexes, enqueues, OS statistics, genuine Oracle reports, RAC analyses, special events | [Session waits](session-waits.md), [Segment statistics](segment-statistics.md), [Genuine Oracle reports](genuine-oracle-reports.md), [Dynamic remastering](dynamic-remastering.md), [Long-term trend analysis](long-term-trend-analysis.md) |
| "Schema / Storage" | disk storage summary, datafiles, UNDO, tablespace objects, object size evolution, describe object, invalid objects, recycle bin, materialized views, table dependencies, TEMP usage, Exadata, ASM | [Describe object](describe-object.md), [Storage reorganisation](storage-reorganisation.md), [TEMP usage](temp-usage.md), [Tablespace fragmentation](tablespace-fragmentation.md) |
| "I/O analysis" | I/O history by detail, file type and file | |
| "SGA/PGA-Details" | SQL area (incl. long operations), SGA memory, DB cache, object usage by SQL, PGA statistics, result cache, SQL plan management, comparing execution plans | [SQL area](sql-area.md), [SQL Monitor](sql-monitor.md), [Long operations](long-operations.md), [SGA memory management](sga-memory-management.md), [DB cache usage](db-cache-usage.md), [Result cache](result-cache.md), [SQL plan management](sql-plan-management.md) |
| "Spec. additions" | [Dragnet Investigation](dragnet.md), "Execute with given parameters", SQL worksheet, admin login | |
| "Admin" | only after admin login: sampler configuration, log level, connection pool, usage history, cache store sizes | [Panorama Sampler](panorama-sampler.md), [Client state and security in Panorama](../development/panorama-client-state-and-security.md) |

> **Corrected 2026-10-05.** Until then this table was reconstructed from mentions
> in the posts. It showed "Long-term trend" as a top-level menu (it is an entry
> under "Analyses / statistics" / "Session-Waits") and lacked the top-level menus
> "I/O analysis" and "Admin". Its placement of "long operations" under "SGA/PGA
> details" was first marked as wrong, because the menu overview generated on
> 2026-09-02 had no such entry; the overview regenerated later the same day
> lists it under "SQL-Area", so the old table was right on that point.

## Individual functions from the sources

- **Real-time dashboard** ("DBA general"/"Dashboard", since 2021): active
  sessions by wait class over time, plus top sessions and top SQL. On each
  refresh only the delta is transferred; if you select a time range in the chart
  or drill down via a link, the automatic refresh pauses. Requires [ASH](ash.md) — or
  [Panorama Sampler](panorama-sampler.md).
- **Server trace files** ("DBA general"/"Server Files", from DB 12.2): listing
  and viewing trace files via SQL through `V$DIAG_TRACE_FILE` and
  `V$DIAG_TRACE_FILE_CONTENTS`. The explicit purpose: to enable people
  **without** file system rights on the database server — developers, say — to
  inspect the trace files they produced themselves. See
  [Optimizer diagnostics](optimizer-diagnostics.md), [SQL trace](sql-trace.md).
- **Genuine Oracle reports** embedded: Performance Hub (from 12.1) and SQL
  Monitor reports → [SQL Monitor](sql-monitor.md).
- **Pluggable databases** have been supported since 2016 →
  [Pluggable databases](pluggable-databases.md).

## Its role in index analysis

A worked example of how Panorama bundles Oracle mechanics
([Blog series on indexing](../sources/blog-indexing.md), 2019-12-27): for the four roles from [Indexing](indexing.md) it
delivers **one** list that brings together the usage state from
`sys.OBJECT_USAGE` with statements on uniqueness, foreign key protection and
partition exchange eligibility — including the row count of the referenced table
and its DML counts since the last analysis. The four individual checks you would
otherwise have to assemble by hand thus sit side by side in a single row.

## What it is for, in the author's words

([Talks on Panorama and the Panorama Sampler](../sources/talks-panorama-and-sampler.md), ODTUG talk of 2024-01, slide 8.) The focus:

- preparing complex database internals for use **without deep insider knowledge**
- supporting an analysis *workflow* by linking the individual steps in a web GUI
  — "as an alternative to a loving collection of individual SQL scripts"
- drilling down to the root cause, starting from a concrete problem
- **offline analysis at a distance in time** from the problem
- "lowering the barriers to actually getting to the bottom of problems"

And what it does not claim: to cover all facets of monitoring. Functions are
included when established tools do not offer them, offer them insufficiently, or
are not accessible to normal users — for cost reasons, for example. It is meant
to be used *in combination with* tools such as EM Cloud Control, not instead of
them.

The stance behind the catalogue of system-wide checks is described in
[Proactive performance tuning](proactive-performance-tuning.md).

**Menus named in the talks** (written before the table above was replaced on
2026-10-05; all are confirmed by [Panorama menu overview](panorama-menu-overview.md)): "Analyses / statistics"
/ "Segment statistics" and "OS statistics"; "I/O analysis" / "I/O history by
files"; "SGA/PGA details" / "DB cache" (current usage, historic usage from the
sampler, cache advice); "Schema / Storage" / "Describe object" and "Disc storage
summary". Compression suggestion lists and a per-row compression check are
described in [Table, index and LOB compression compared](advanced-compression.md).

**Tip from the same talk:** start Panorama with `PANORAMA_LOG_LEVEL=debug` and
every SQL it executes is written to the server log — the way to learn the
queries behind a view ([Panorama configuration](../development/panorama-configuration.md)).

## How it is built

The inside of the tool is described in the development half of this wiki,
starting at [Panorama architecture](../development/panorama-architecture.md). Three of the properties above have a
direct counterpart there ([Panorama source repository](../sources/panorama-source-code.md)):

- *Licence-aware* is a text filter every SQL statement passes
  → [Pack licence filter](../development/pack-license-filter.md).
- *Every cell is a link, every table becomes a chart* follows from one grid
  generator and fragment-wise rendering → [Controllers, routing and rendering in Panorama](../development/panorama-request-and-rendering.md).
- *States are shareable* works because a view is fully described by controller,
  action and parameters.

## The website's account

([Panorama's website on GitHub Pages](../sources/rammpeter-github-io.md), landing page.) What the tool's own front page adds to
the picture above:

- **Audience:** DBAs "and also … software developers with less Oracle
  knowledge". It "aims to many issues that are inadequately analyzed and
  presented by other existing tools such as Enterprise Manager".
- **Read-only, stated strictly:** "Panorama only reads via SELECT-SQLs from
  database. No write access, own database objects, compile etc. is needed at
  your database." (The exception is [Panorama Sampler](panorama-sampler.md), which writes into a
  schema of its own.)
- **Platforms:** standard hardware, RAC, engineered systems (Exadata) and
  Autonomous Database in OCI; tested from Oracle 11.2.
- **Licence:** GNU General Public License v3, free of charge.
- **Requirements:** Java 21 or higher (or a container runtime), a browser with
  ES6 support, and a database user with at least `SELECT ANY DICTIONARY`
  → [Privileges for Panorama](panorama-privileges.md).
- **Try it:** a public demo installation → [Panorama operations](panorama-operations.md).
- **Further resources linked there:** the blog ([rammpeter.blogspot.com](rammpeter-blog.md)), the slide
  decks ([Talks and slide decks by Peter Ramm](rammpeter-talks.md)), an older deck collection on slideshare, and a
  video of a presentation at ODTUG (<https://www.youtube.com/watch?v=JYHRArXagSg>).

How an analysis is laid out — two ways, three pillars — and how the interface is
driven (workflow grows downwards, context menu, pinning tables) is described in
[Analysis workflows in Panorama](panorama-analysis-workflows.md).

## Relationships

- Data foundations: [AWR](awr.md), [ASH](ash.md), alternatively [Panorama Sampler](panorama-sampler.md).
- Components: [Dragnet Investigation](dragnet.md), [Panorama Sampler](panorama-sampler.md), [Panorama operations](panorama-operations.md).
- Licensing model: [Management pack licensing](management-pack-licensing.md).
- Demonstrated in roughly half the posts of [rammpeter.blogspot.com](rammpeter-blog.md).
- The author's talks demonstrating it: [Talks and slide decks by Peter Ramm](rammpeter-talks.md).
- All menu entries: [Panorama menu overview](panorama-menu-overview.md); working with it:
  [Analysis workflows in Panorama](panorama-analysis-workflows.md); needed grants: [Privileges for Panorama](panorama-privileges.md).

## Open questions

- ~~The architecture is known only from the repository, not from a source in
  `raw/`.~~ Closed 2026-10-03: the repository is now a source
  ([Panorama source repository](../sources/panorama-source-code.md)) → [Panorama architecture](../development/panorama-architecture.md).
- Which Oracle versions are supported? The website says "tested against Oracle
  database versions beginning with Oracle 11.2" ([Panorama's website on GitHub Pages](../sources/rammpeter-github-io.md)).
  Partly answered before: CI tests 11.2.0.4 up to
  23.5 and an autonomous database ([Building, testing and releasing Panorama](../development/panorama-build-test-and-release.md)); the
  code still branches for older releases. *Where* the version changes an
  evaluation is still open.
- ~~The menu structure above is reconstructed from mentions across 14 years of
  posts — it may have changed since and is incomplete.~~ Closed 2026-10-05:
  [Panorama menu overview](panorama-menu-overview.md) reproduces the overview generated from the source
  code. New gap: 58 of its 124 entries have no page.
- Two described functions (SQL Monitor report, Performance Hub) required Adobe
  Flash, which has been discontinued since the end of 2020. Answered 2026-10-05
  for the SQL Monitor report ([SQL Monitor](sql-monitor.md)); still open for the Performance
  Hub ([Genuine Oracle reports](genuine-oracle-reports.md)).

## Sources

- [Blog series on Panorama as a tool](../sources/blog-panorama-the-tool.md)
- [Blog series on indexing](../sources/blog-indexing.md)
- [Blog series on system load and monitoring](../sources/blog-system-load.md)
- [rammpeter.blogspot.com](rammpeter-blog.md)
- [Panorama source repository](../sources/panorama-source-code.md)
- [Talks on Panorama and the Panorama Sampler](../sources/talks-panorama-and-sampler.md)
- [Panorama's website on GitHub Pages](../sources/rammpeter-github-io.md)
