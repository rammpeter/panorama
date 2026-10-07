---
title: Dragnet Investigation
type: entity
subtype: component
status: draft
tags: [panorama]
created: 2026-10-01
updated: 2026-10-05
sources: [blog.md, posts/, panorama-repository.md, speakerdeck.md, speakerdeck/, rammpeter.github.io.md, rammpeter.github.io/]
---

# Dragnet Investigation

Panorama's catalogue of ready-made search queries: system-wide scans that comb an
entire database system for a known problem pattern instead of investigating a
single case. Found under the menu "Spec. additions" / "Dragnet investigation".

## Summary

What distinguishes it from the rest of [Panorama](panorama.md) is the direction of the
question: the normal views answer "what is wrong with *this* SQL / *this*
session?", dragnet answers "where in my system does *this pattern* occur?". Hits
are sorted by relevance, and from there links lead into the detail views.

The entries are numbered and are cited in the blog posts by their number (e.g.
"point 1.2" for superfluous indexes, "point 2.6" for changing execution plans).

> Older assessment, from the blog alone (2026-10-01): "the numbering appears to
> have been stable over the years". **Superseded 2026-10-03.** In the code an
> entry has no identifier of its own, only its position in the tree
> ([Controllers, routing and rendering in Panorama](../development/panorama-request-and-rendering.md)) — so numbers shift when entries are
> inserted. The blog itself shows one such shift (4.1–4.3 became 4.1.1–4.1.5).
> Treat a cited number as valid for the release of the post, and search by the
> entry's name otherwise.
>
> **Confirmed by a source, 2026-10-04:** "TABLE ACCESS BY INDEX ROWID with
> additional filter predicates" is point 1.11 in the talk of 2018 and point 1.15
> in the talk of 2026 ([Talks on dragnet investigation and proactive tuning](../sources/talks-dragnet-and-proactive-tuning.md)).

## Why it exists

([Talks on dragnet investigation and proactive tuning](../sources/talks-dragnet-and-proactive-tuning.md)) The idea: once a problem has been
analysed, express its *recognition* as a SQL statement over dictionary, SGA
views and AWR history, and find every other occurrence in the system, weighted
by potential. The solutions aimed at are those that can be implemented "without
interfering with architecture and design". The stance is described in
[Proactive performance tuning](proactive-performance-tuning.md).

Two limits stated by the author himself: the selections are **"not an automated
to-do list generator"** — judging each hit, and discarding those without
relevance, is mandatory; and the catalogue covers "only the topics I was
personally confronted with in projects".

**Size over time:** "just under 100" aspects (2018), "140+ predefined checks"
(2026); the code read in October 2026 contains roughly 150 SQL entries
([Controllers, routing and rendering in Panorama](../development/panorama-request-and-rendering.md)).

**Without Panorama:** the complete list of the SQL statements is published at
<https://rammpeter.github.io/oracle_performance_tuning.html>.

## Extensibility

([rammpeter.blogspot.com](rammpeter-blog.md), 2016-03-20)

- Via "Add personal selection" in the "≡" menu, **your own SQL** can be added. It
  resides on the Panorama server instance and is visible only to your own browser
  instance; it appears under a separate menu entry "Personal extensions".
- To make it permanent and available to all users of a Panorama instance, it is
  stored as a JSON array in a file `predefined_dragnet_selections.json` in the
  directory `PANORAMA_VAR_HOME`.

## Known entries from the blog

- List superfluous indexes (point 1.2) → [Indexing](indexing.md)
- Unused indexes across all schemas → [Index usage monitoring](index-usage-monitoring.md)
- Recommendation lists for index compression → [Index compression](index-compression.md)
- Index access with skipped columns → [Index access paths](index-access-paths.md)
- Statements with changing execution plans (point 2.6) → [Execution plans](execution-plans.md)
- SQL with literals instead of bind variables (points 4.1 to 4.3, later 4.1.1 to
  4.1.5) → [Bind variables and cursor sharing](bind-variables-and-cursor-sharing.md)
- Extremely short-running SQL in parallel query mode → [ASH](ash.md)
- Inappropriate sequence caches (points 3.8 and 3.9) → [Sequence caching](sequence-caching.md)
- SQL where parallel DML or direct load does not work (point 2.2.12) and
  candidates for the shared hash join (point 2.2.11) → [Parallel execution](parallel-execution.md)
- Estimating network latency → [Estimating network latency from ASH](network-latency-from-ash.md)
- SQL missing partition pruning → [Partition pruning](partition-pruning.md)
- Functions without a `DETERMINISTIC` flag → [DETERMINISTIC](deterministic.md)

## Further entries named in the talks

Numbers as of the talk in which they appear.

- Indexes with only one or few key values (1.2.2, 2018) →
  [Function-based indexes](function-based-indexes.md), [Indexing](indexing.md)
- Indexes whose columns are a leading subset of another index (1.2.3)
  → [Indexing](indexing.md)
- Indexes on partitioned tables repeating the partition key (1.2.8, 2018)
  → [Partition pruning](partition-pruning.md)
- Foreign keys with a potentially missing index (1.7.1, 2026) and with a
  potentially unnecessary one (1.2.6, 2026) → [Foreign keys and locks](foreign-key-locks.md)
- Tables with `PCT_FREE` > 0 but without updates (1.2.10, 2026)
  → [Proactive performance tuning](proactive-performance-tuning.md)
- `TABLE ACCESS BY INDEX ROWID` with additional filters (1.11 in 2018, 1.15 in
  2026) → [Index access paths](index-access-paths.md)
- Parallel plans forced to serial, `PX COORDINATOR FORCED SERIAL` (2.2.8, 2018)
  → [Parallel execution](parallel-execution.md)
- Full table scans with small cardinality (2.1.3, 2026)
- Frequent access to small objects (2.4.2, 2026) → [Master data caching](master-data-caching.md)
- Unnecessarily high fetch count (2.4.3, 2026) and JDBC statement cache probably
  not used (4.2.2, 2026) → [Proactive performance tuning](proactive-performance-tuning.md)

## Relationships

- A component of [Panorama](panorama.md).
- Many entries require [AWR](awr.md) or [ASH](ash.md) and therefore a licence per
  [Management pack licensing](management-pack-licensing.md).
- The website says "more than 100 considered aspects" and the usage guide "over
  100 different performance antipatterns", against "140+" in the 2026 talk and
  roughly 150 in the code — the website has not kept up
  ([Panorama's website on GitHub Pages](../sources/rammpeter-github-io.md)). The guide calls the menu "Special extensions"; the
  generated menu overview has "Spec. additions" / "Dragnet investigation"
  ([Panorama menu overview](panorama-menu-overview.md)).

## Open questions

- ~~How many entries does the catalogue contain, and how is it structured?~~
  Answered 2026-10-03 from [Panorama source repository](../sources/panorama-source-code.md): roughly 150 SQL entries in
  eight top-level groups (DB structures, problematic execution plans,
  long-running SQL, SGA/PGA tuning, log writer and redo, conclusions on
  application behaviour, PL/SQL usage, instance setup) — see
  [Controllers, routing and rendering in Panorama](../development/panorama-request-and-rendering.md).
- Custom entries under version control: the built-in catalogue *is* in the
  repository (`app/helpers/dragnet/`), so a contribution there is the
  version-controlled route. For site-specific entries only the JSON file in
  `PANORAMA_VAR_HOME` exists.
- Is there a stable way to refer to an entry, given that numbers shift?
- Which of the checks need AWR or ASH, and which run on dictionary and SGA
  alone? Neither talk nor code read so far gives the split.

## Sources

- [Blog series on indexing](../sources/blog-indexing.md)
- [Blog series on Panorama as a tool](../sources/blog-panorama-the-tool.md)
- [rammpeter.blogspot.com](rammpeter-blog.md)
- [Panorama source repository](../sources/panorama-source-code.md)
- [Talks on dragnet investigation and proactive tuning](../sources/talks-dragnet-and-proactive-tuning.md)
- [Panorama's website on GitHub Pages](../sources/rammpeter-github-io.md)
