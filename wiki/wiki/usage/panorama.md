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

The author's own description ([[blog-indexing]], 2019-12-27):

> "Panorama is the author's Swiss Army Knife, a freely usable tool for Oracle-DB
> performance analysis. It is based on read-only SQL-accessible information of
> the DB, including data from the AWR."

Four properties characterise the tool:

- **Read-only.** Panorama relies exclusively on information readable via SQL.
  Where it would intervene by changing something, it instead generates a snippet
  for you to execute yourself — for SQL plan baselines, SQL patches and SQL
  translations ([[sql-plan-management]], [[sql-translation-framework]]).
- **Freely available**, as a JAR and as a Docker image →
  [[panorama-operations]].
- **Licence-aware.** The licensing model is built into the workflow, not glued
  on → [[management-pack-licensing]].
- **Usable without the Diagnostics Pack**, via [[panorama-sampler]] — whose data
  is evaluated *transparently in the same place* as real AWR/ASH.

## Recurring patterns of the interface

Evidenced again and again across the posts — they give the tool its actual
character:

- **Every cell is a link** that leads one level deeper: from the minute into the
  ASH records, from the session into its SQL, from the plan line into the wait
  events. Several posts describe an analysis purely as a sequence of clicks.
- **Every table becomes a chart**, via the context menu on a column.
- **Colour marks the conspicuous:** orange for the root session of a lock chain
  ([[blocking-locks]]), orange for multiple plans ([[execution-plans]]), pink for
  an ineffective hint ([[optimizer-hints]]), a coloured background for missing
  extended statistics ([[extended-statistics]]).
- **States are shareable.** Filter states you have reached can be copied to the
  clipboard as request parameters and restored later via "Spec. additions /
  Execute with given parameters" — to pass on to colleagues or for a later
  comparison ([[blog-panorama-the-tool]], 2016-11-16).
- **Warnings against misinterpretation.** If a SQL patch or a SQL translation
  exists for a SQL, that is shown in **every** detail view — "to explicitly
  prevent misinterpretation of execution plan".

## Functional domains

The complete menu, entry by entry, is in [[panorama-menu-overview]]
([[rammpeter-github-io]], generated from the source code on 2026-10-05). In
short:

| Menu | Content | See |
|---|---|---|
| "DBA general" | start page, dashboard, DB locks, redo logs, sessions, database configuration, user management, audit trail, server files, database triggers, DB links, scheduled jobs, feature usage, patch history | [[blocking-locks]], [[redo-logs]], [[session-list]], [[database-configuration]], [[audit-trail]] |
| "Analyses / statistics" | session waits (incl. long-term trend), segment statistics, system events, statistics and metrics, time model, latches, mutexes, enqueues, OS statistics, genuine Oracle reports, RAC analyses, special events | [[session-waits]], [[segment-statistics]], [[genuine-oracle-reports]], [[dynamic-remastering]], [[long-term-trend-analysis]] |
| "Schema / Storage" | disk storage summary, datafiles, UNDO, tablespace objects, object size evolution, describe object, invalid objects, recycle bin, materialized views, table dependencies, TEMP usage, Exadata, ASM | [[describe-object]], [[storage-reorganisation]], [[temp-usage]], [[tablespace-fragmentation]] |
| "I/O analysis" | I/O history by detail, file type and file | |
| "SGA/PGA-Details" | SQL area (incl. long operations), SGA memory, DB cache, object usage by SQL, PGA statistics, result cache, SQL plan management, comparing execution plans | [[sql-area]], [[sql-monitor]], [[long-operations]], [[sga-memory-management]], [[db-cache-usage]], [[result-cache]], [[sql-plan-management]] |
| "Spec. additions" | [[dragnet]], "Execute with given parameters", SQL worksheet, admin login | |
| "Admin" | only after admin login: sampler configuration, log level, connection pool, usage history, cache store sizes | [[panorama-sampler]], [[panorama-client-state-and-security]] |

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
  or drill down via a link, the automatic refresh pauses. Requires [[ash]] — or
  [[panorama-sampler]].
- **Server trace files** ("DBA general"/"Server Files", from DB 12.2): listing
  and viewing trace files via SQL through `V$DIAG_TRACE_FILE` and
  `V$DIAG_TRACE_FILE_CONTENTS`. The explicit purpose: to enable people
  **without** file system rights on the database server — developers, say — to
  inspect the trace files they produced themselves. See
  [[optimizer-diagnostics]], [[sql-trace]].
- **Genuine Oracle reports** embedded: Performance Hub (from 12.1) and SQL
  Monitor reports → [[sql-monitor]].
- **Pluggable databases** have been supported since 2016 →
  [[pluggable-databases]].

## Its role in index analysis

A worked example of how Panorama bundles Oracle mechanics
([[blog-indexing]], 2019-12-27): for the four roles from [[indexing]] it
delivers **one** list that brings together the usage state from
`sys.OBJECT_USAGE` with statements on uniqueness, foreign key protection and
partition exchange eligibility — including the row count of the referenced table
and its DML counts since the last analysis. The four individual checks you would
otherwise have to assemble by hand thus sit side by side in a single row.

## What it is for, in the author's words

([[talks-panorama-and-sampler]], ODTUG talk of 2024-01, slide 8.) The focus:

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
[[proactive-performance-tuning]].

**Menus named in the talks** (written before the table above was replaced on
2026-10-05; all are confirmed by [[panorama-menu-overview]]): "Analyses / statistics"
/ "Segment statistics" and "OS statistics"; "I/O analysis" / "I/O history by
files"; "SGA/PGA details" / "DB cache" (current usage, historic usage from the
sampler, cache advice); "Schema / Storage" / "Describe object" and "Disc storage
summary". Compression suggestion lists and a per-row compression check are
described in [[advanced-compression]].

**Tip from the same talk:** start Panorama with `PANORAMA_LOG_LEVEL=debug` and
every SQL it executes is written to the server log — the way to learn the
queries behind a view ([[panorama-configuration]]).

## How it is built

The inside of the tool is described in the development half of this wiki,
starting at [[panorama-architecture]]. Three of the properties above have a
direct counterpart there ([[panorama-source-code]]):

- *Licence-aware* is a text filter every SQL statement passes
  → [[pack-license-filter]].
- *Every cell is a link, every table becomes a chart* follows from one grid
  generator and fragment-wise rendering → [[panorama-request-and-rendering]].
- *States are shareable* works because a view is fully described by controller,
  action and parameters.

## The website's account

([[rammpeter-github-io]], landing page.) What the tool's own front page adds to
the picture above:

- **Audience:** DBAs "and also … software developers with less Oracle
  knowledge". It "aims to many issues that are inadequately analyzed and
  presented by other existing tools such as Enterprise Manager".
- **Read-only, stated strictly:** "Panorama only reads via SELECT-SQLs from
  database. No write access, own database objects, compile etc. is needed at
  your database." (The exception is [[panorama-sampler]], which writes into a
  schema of its own.)
- **Platforms:** standard hardware, RAC, engineered systems (Exadata) and
  Autonomous Database in OCI; tested from Oracle 11.2.
- **Licence:** GNU General Public License v3, free of charge.
- **Requirements:** Java 21 or higher (or a container runtime), a browser with
  ES6 support, and a database user with at least `SELECT ANY DICTIONARY`
  → [[panorama-privileges]].
- **Try it:** a public demo installation → [[panorama-operations]].
- **Further resources linked there:** the blog ([[rammpeter-blog]]), the slide
  decks ([[rammpeter-talks]]), an older deck collection on slideshare, and a
  video of a presentation at ODTUG (<https://www.youtube.com/watch?v=JYHRArXagSg>).

How an analysis is laid out — two ways, three pillars — and how the interface is
driven (workflow grows downwards, context menu, pinning tables) is described in
[[panorama-analysis-workflows]].

## Relationships

- Data foundations: [[awr]], [[ash]], alternatively [[panorama-sampler]].
- Components: [[dragnet]], [[panorama-sampler]], [[panorama-operations]].
- Licensing model: [[management-pack-licensing]].
- Demonstrated in roughly half the posts of [[rammpeter-blog]].
- The author's talks demonstrating it: [[rammpeter-talks]].
- All menu entries: [[panorama-menu-overview]]; working with it:
  [[panorama-analysis-workflows]]; needed grants: [[panorama-privileges]].

## Open questions

- ~~The architecture is known only from the repository, not from a source in
  `raw/`.~~ Closed 2026-10-03: the repository is now a source
  ([[panorama-source-code]]) → [[panorama-architecture]].
- Which Oracle versions are supported? The website says "tested against Oracle
  database versions beginning with Oracle 11.2" ([[rammpeter-github-io]]).
  Partly answered before: CI tests 11.2.0.4 up to
  23.5 and an autonomous database ([[panorama-build-test-and-release]]); the
  code still branches for older releases. *Where* the version changes an
  evaluation is still open.
- ~~The menu structure above is reconstructed from mentions across 14 years of
  posts — it may have changed since and is incomplete.~~ Closed 2026-10-05:
  [[panorama-menu-overview]] reproduces the overview generated from the source
  code. New gap: 58 of its 124 entries have no page.
- Two described functions (SQL Monitor report, Performance Hub) required Adobe
  Flash, which has been discontinued since the end of 2020. Answered 2026-10-05
  for the SQL Monitor report ([[sql-monitor]]); still open for the Performance
  Hub ([[genuine-oracle-reports]]).

## Sources

- [[blog-panorama-the-tool]]
- [[blog-indexing]]
- [[blog-system-load]]
- [[rammpeter-blog]]
- [[panorama-source-code]]
- [[talks-panorama-and-sampler]]
- [[rammpeter-github-io]]
