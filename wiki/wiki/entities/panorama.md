---
title: Panorama
type: entity
subtype: product
status: draft
tags: [core]
created: 2026-10-01
updated: 2026-10-02
sources: [blog.md, posts/]
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

| Menu | Content | See |
|---|---|---|
| "DBA general" | DB locks, redo logs, audit trail, dashboard, server files | [[blocking-locks]], [[redo-logs]], [[audit-trail]] |
| "SGA/PGA details" | SQL area, SQL plan management, result cache, SGA components, DB cache, long operations | [[sql-plan-management]], [[result-cache]], [[sga-memory-management]], [[long-operations]] |
| "Analyses / statistics" | session waits, latch statistics, RAC analyses, genuine AWR reports | [[dynamic-remastering]], [[sql-monitor]] |
| "Schema / Storage" | table and index structure, TEMP usage, disk storage summary | [[indexing]], [[temp-usage]], [[tablespace-fragmentation]] |
| "Spec. additions" | [[dragnet]], "Execute with given parameters" | |
| "Long-term trend" | condensed long-term data | [[long-term-trend-analysis]] |

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

## Relationships

- Data foundations: [[awr]], [[ash]], alternatively [[panorama-sampler]].
- Components: [[dragnet]], [[panorama-sampler]], [[panorama-operations]].
- Licensing model: [[management-pack-licensing]].
- Demonstrated in roughly half the posts of [[rammpeter-blog]].

## Open questions

- The architecture (Rails on JRuby, a connection established per request, no
  persistent database of its own) is so far known only from the repository, not
  from a source in `raw/`.
- Which Oracle versions are supported, and where does that affect the
  evaluations?
- The menu structure above is reconstructed from mentions across 14 years of
  posts — it may have changed since and is incomplete.
- Two described functions (SQL Monitor report, Performance Hub) required Adobe
  Flash, which has been discontinued since the end of 2020. The current state is
  not evidenced.

## Sources

- [[blog-panorama-the-tool]]
- [[blog-indexing]]
- [[blog-system-load]]
- [[rammpeter-blog]]
