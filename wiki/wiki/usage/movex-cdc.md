---
title: MOVEX CDC
type: entity
subtype: external
status: draft
tags: [tool, partitioning, architecture]
created: 2026-10-04
updated: 2026-10-04
sources: [speakerdeck.md, speakerdeck/2022-05_MOVEX_CDC_DOAG_Database_en.pdf]
---

# MOVEX CDC

"MOVEX Change Data Capture": an open-source tool by Panorama's author that
captures data changes in a relational database with triggers and delivers them
as JSON events to Kafka. Not part of [[panorama]], but built on the same
technical base and instructive as a piece of Oracle design. Available at
<https://gitlab.com/osp-silver/oss/movex-cdc>.

## Summary

([[talks-jarbler-and-movex-cdc]], talk of 2022-05.) GPL3, developed at Otto
Group Solution Provider; project at <https://gitlab.com/osp-silver/oss/movex-cdc>,
Docker image
`ottogroupsolutionproviderosp/movex-cdc`. Supported databases: Oracle (all
editions, optimised for Enterprise Edition with partitioning) and SQLite;
others were planned.

> **Project location.** The 2022 slides give
> `https://gitlab.com/otto-group-solution-provider/movex-cdc` and documentation
> under `otto-group-solution-provider.gitlab.io`. The current address above was
> stated by the author on 2026-10-04; the older one is kept here as what the
> source says. Whether the documentation and the Docker image moved as well is
> not known.

## Why triggers and not the redo log

Established CDC tools (GoldenGate, SharePlex, Debezium) mostly scan the
transaction logs. That leaves the original transaction untouched — but:

- To compensate automatically for an unavailable target, the logs must be kept
  for the longest assumed outage; allowing for reaction times and weekends,
  "usually at least 3 days".
- If only a small share of all changes is relevant, handling the whole log is
  disproportionate effort and complexity.

The trigger approach filters at the moment of the change. Its price is stated
just as plainly: the original transaction writes twice.

| Pro | Contra |
|---|---|
| no dependency on, or complexity in, database operations | load on the original transaction (double write) |
| no change to existing applications | possibly downtime for trigger deployment and updates |
| relevant events filtered when they occur | operational risks of all participants become coupled |

## The design, and the Oracle reasoning in it

**Decoupling by a staging table.** The trigger only inserts into a table
`EVENT_LOGS` in MOVEX CDC's own schema. The business transaction therefore never
depends on Kafka or on the MOVEX CDC application being up. If the application is
stopped, events accumulate and are delivered later — which allows updates during
production.

**Compound trigger with bulk insert.** The row trigger collects JSON records in
a PL/SQL collection (at most 1,000) and writes them in bulk at statement end;
the collection is cleared `BEFORE STATEMENT` to drop fragments of a failed
predecessor.

**A staging table without any index** (Enterprise Edition with partitioning).
Interval-partitioned, no index: minimal overhead and maximum availability for
the inserting transactions. Reading is then a full scan — kept bounded because
fully processed partitions are dropped promptly. "No problem with a
non-reducible high water mark": after a burst, the next partition starts small
again → [[interval-partitions-rolling-window]].

**The same on Standard Edition shows what partitioning was buying.** There the
table is a heap table with an index on `ID`: extra index maintenance in the
business transaction, "a very tiny risk" of blocking at index block splits, and a
high water mark that stays up after a peak — to be reset by hand with
`ALTER TABLE Event_Logs MOVE` and an index rebuild → [[storage-reorganisation]].

**Work distribution by row locks.** Worker threads take events with
`SELECT … FOR UPDATE SKIP LOCKED`; no coordinator is needed, and in principle
several instances could run in parallel.

**Ordering is guaranteed only per key.** Kafka preserves order only within a
partition, and events with the same key land in the same partition. MOVEX CDC
hashes the key to exactly one worker thread. Without a key there is no ordering —
a deliberate trade against parallelism. One residual case is named: a
transaction that commits *after* a later one with the same key has already been
transferred.

**No distributed transaction.** Database and Kafka are coupled by two nested
local transactions, not XA; a "tiny hypothetical risk" of duplicate delivery
remains.

**Fault handling by divide and conquer.** When a bulk transfer is rejected, the
batch is halved until the single offending event is isolated; it is retried with
a delay and finally moved to an error table.

**The 4 KB edge.** From 4 KB of JSON upward, Oracle stores the payload as a
CLOB, "significantly slower" than in the row.

**Measured:** 820,000 events per minute (1.18 billion per day) with three worker
threads, small distances and JSON under 4 KB.

## What it shares with Panorama

- Ruby on Rails on JRuby, delivered as one Docker image
- configuration by a config file or environment variables
- logging to the console, log level changeable at runtime
- the database schema **initialises itself** at start — the pattern of the
  sampler's structure check ([[panorama-sampler-internals]])
- worker threads inside the application process, each with its own database
  session ([[panorama-architecture]])

## Relationships

- By the author of [[panorama]]; presented in [[rammpeter-talks]].
- Applies [[interval-partitions-rolling-window]] and illustrates
  [[storage-reorganisation]].
- Compound triggers also carry the solution in [[cross-table-uniqueness]].

## Open questions

- Did the documentation pages and the Docker Hub image move along with the
  repository?
- The talk is from 2022. Which of the planned databases (PostgreSQL, SQL Server,
  MySQL) were added since?
- How does trigger deployment avoid invalidating cursors and blocking DML on a
  busy table? The talk only lists "possibly downtime" as a drawback.

## Sources

- [[talks-jarbler-and-movex-cdc]]
