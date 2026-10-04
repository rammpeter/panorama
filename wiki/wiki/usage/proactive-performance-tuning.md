---
title: Proactive performance tuning
type: concept
status: draft
tags: [core, tuning, dragnet]
created: 2026-10-04
updated: 2026-10-04
sources: [speakerdeck.md, speakerdeck/2018-11_DOAG-Dresden_Systematische_Rasterfahndung_nach_Performance-Antipattern.pdf, speakerdeck/2026-05_DOAG_Datenbank_Firefighting_or_Fixing_Root_Causes.pdf, speakerdeck/2024-01_ODTUG_Performance_Analysis_with_Panorama.pdf]
---

# Proactive performance tuning

The stance behind much of [[panorama]]: do not wait for the incident. Look for
every occurrence of a known problem pattern across the whole system, rank the
hits, and fix the cheap ones before anyone complains.

## Summary

Two talks eight years apart argue the same case
([[talks-dragnet-and-proactive-tuning]]). The 2026 title puts it as a question —
"Firefighting or fixing root causes?" — and the answer is not either/or: the tool
supports both, but only one of them uses the system's potential.

## Where performance comes from

The frame the newer talks open with: eight factors that influence performance in
database use.

| Factor | What matters |
|---|---|
| Compute node | number and speed of cores; capacity, latency and bandwidth of memory |
| I/O system | throughput, latency, capacity |
| Network | bandwidth, latency |
| DB instance | configuration; redo, undo, temp |
| DB segments | tables, indexes, clusters, partitions |
| DB sessions | the link between application and database, transactional behaviour, optimizer settings |
| SQL statements | executed operations, execution plans |
| Application | process design, data model, database access, transactions |

> Conclusion: the list runs from what money buys to what only design fixes. The
> pages of this wiki sit almost entirely in the lower half — segments, sessions,
> SQL, application — which is also where proactive scanning can find anything.

## Two approaches

| | Reactive ("firefighting") | Proactive |
|---|---|---|
| Trigger | broken SLA, business complaint | none — continuous |
| Effect per measure | high | successively lower |
| Use of the potential | only in spots | largely |
| Hardware and licences | possibly more than necessary | used efficiently |
| Cost of the tuning work | lower | rising with each further step |
| What gets fixed | the occurrence currently visible | all occurrences of the pattern |

(2018 slide 4, 2026 slide 7.) The reactive column is not a caricature: its cost
is lower and each measure pays off visibly. The argument for the proactive
column is the last row.

**Why a ranked list changes the work** (2026, slide 7). A list of all
occurrences of one scenario, ordered by severity, lets you rate how relevant a
suboptimal behaviour really is, check whether a lightweight fix exists, and
estimate its benefit. And looking at the same type of problem row by row "often
allows to apply the same solution approach multiple times".

## What makes it possible

- **The database keeps traces.** Dictionary, SGA views and — given the licence
  or the [[panorama-sampler]] — the AWR and ASH history
  ([[awr]], [[ash]]). `V$SQL` and `DBA_Hist_SQLStat` alone answer: which SQL
  takes most time in total, which per execution, which needs most buffer gets
  per row.
- **A recognised problem can be written as a query.** That is the whole idea of
  [[dragnet]]: formulate the identification as SQL, run it system-wide, sort by
  potential.
- **Solutions should be simple**: "as simple as possible to implement without
  interfering with architecture and design" (2018). The catalogue is biased
  towards fixes that need no redesign.

## What it is not

The 2018 talk is explicit: the selections "are not an automated to-do list
generator". Expert judgement of every suggestion is mandatory, including
discarding hits that have no practical relevance. A hit is a question, not a
verdict — which is why each one links into the object, its SQL, the plans and the
history.

And it is bounded by one person's experience: the catalogue addresses "only the
topics I was personally confronted with in projects".

## Examples that are advice to developers

Three of the 2026 examples have nothing to do with the database's
configuration; they are about how the application talks to it.

**Cache small master data in the application** (point 2.4.2). Frequently
executed selects on small objects cost CPU and risk "cache buffers chains" latch
waits; a remote application also saves the network round trips. Function result
cache or SQL result cache are the in-database alternatives →
[[master-data-caching]], [[result-cache]].

**Fetch in bulk** (point 2.4.3). For larger results, fetching many rows per call
barely reduces database CPU — but for a remote client it removes round trips
that may each take longer than the fetch itself. SQL\*Plus: `SET ARRAYSIZE`;
JDBC per statement: `setFetchSize(n)`; JDBC globally: the connection property
`defaultRowPrefetch` → [[network-latency-from-ash]].

**Switch on the JDBC statement cache** (point 4.2.2). A high soft parse rate on
JDBC thin connections suggests the client-side statement cache is off or too
small — and **it is off by default** in Oracle's driver.

```java
((OracleConnection) conn).setImplicitCachingEnabled(true);
((OracleConnection) conn).setStatementCacheSize(100);
```

or, from 19c, in the URL:
`jdbc:oracle:thin:@host:1521/srv?oracle.jdbc.implicitStatementCacheSize=100`.

> Panorama does exactly this for its own connections, with the same two calls
> and the same size ([[panorama-connection]]).

Further examples, with their own pages: redundant and unused indexes
([[indexing]], [[index-usage-monitoring]]), foreign keys with a missing or a
superfluous index ([[foreign-key-locks]],
[[do-not-blanket-index-foreign-keys]]), missing bind variables
([[bind-variables-and-cursor-sharing]]), index compression
([[index-compression]]).

**`PCT_FREE` without updates** (point 1.2.10). Free space reserved per block
serves two purposes: room for rows that grow on update, and room for the ITL to
grow beyond `INI_TRANS`. A table without any update since the last analysis
needs the first not at all; if it does not need the second either, `PCTFREE 0`
and a reorganisation free the space → [[storage-reorganisation]].

## Relationships

- The instrument: [[dragnet]] in [[panorama]].
- The data it rests on: [[awr]], [[ash]], [[segment-statistics]]; without a
  licence [[panorama-sampler]].
- The same stance applied to one topic in depth: [[indexing]].
- Planning ahead rather than reacting, at the scale of years:
  [[long-term-trend-analysis]].

## Open questions

- The comparison names the rising effort of preventive tuning but gives no
  criterion for when to stop.
- Is there evidence — from the author's own systems — of what a systematic pass
  saved in hardware or licences? The talks assert the effect, they do not
  quantify it.
- Who in a project owns this work? [[indexing]] records the author's diagnosis
  that nobody does.

## Sources

- [[talks-dragnet-and-proactive-tuning]]
- [[talks-panorama-and-sampler]] (the eight factors, 2024 and 2025 decks)
