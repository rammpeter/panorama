---
title: AWR (Automatic Workload Repository)
type: concept
status: stub
tags: [core, oracle]
created: 2026-10-01
updated: 2026-10-02
sources: [blog.md, posts/]
---

# AWR (Automatic Workload Repository)

Oracle's built-in repository that stores snapshots of the internal performance
statistics into `DBA_HIST_*` tables at regular intervals, thereby enabling
historical evaluation across days and weeks.

## Summary

*Stub.* What should be recorded here: what a snapshot contains, the snapshot
interval and retention period, the most important `DBA_HIST_*` views, and the
basic principle of taking the difference between two snapshots. None of the
ingested posts covers AWR itself — they all use it as a given.

## What the ingested sources do say about it

- `DBA_HIST_SQL_PLAN` only populates `Access_Predicates` and
  `Filter_Predicates` from release 19.19 onwards, and old plans stay empty
  forever → [[execution-plans]].
- `DBA_HIST_LOG` yields the status and archived flag of the redo log groups at
  snapshot times → [[redo-logs]].
- `DBA_HIST_SYSMETRIC_SUMMARY` carries I/O and CPU metrics as averages over the
  AWR cycle — which matters for interpretation →
  [[measuring-system-load]].
- `DBA_HIST_SEG_STAT` receives the segment statistics at each snapshot; for a
  finer resolution you have to measure yourself → [[segment-statistics]].
- `DBA_HIST_LATCH` carries the latch statistics → [[result-cache]].
- `DBA_HIST_REPORTS` keeps SQL Monitor reports beyond their short life from
  12.1 onwards → [[sql-monitor]].

## Relationships

- Complements [[ash]]: AWR aggregates over intervals, ASH keeps individual
  samples of active sessions.
- Its use requires a licence — see [[management-pack-licensing]].
- Evaluated by [[panorama]] in the historical analyses; without a licence
  [[panorama-sampler]] takes its place.

## Open questions

- Which AWR views are the most productive in practice?
- How do AWR data behave in RAC environments (evaluation across instances)?
- What exactly does a snapshot contain, and what is the default interval? Not
  covered by any ingested source.

## Sources

- [[blog-execution-plans]]
- [[blog-system-load]]
