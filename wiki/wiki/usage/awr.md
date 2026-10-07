---
title: AWR (Automatic Workload Repository)
type: concept
status: stub
tags: [core, oracle]
created: 2026-10-01
updated: 2026-10-05
sources: [blog.md, posts/, speakerdeck.md, speakerdeck/, rammpeter.github.io.md, rammpeter.github.io/]
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
  forever → [Execution plans](execution-plans.md).
- `DBA_HIST_LOG` yields the status and archived flag of the redo log groups at
  snapshot times → [Redo logs](redo-logs.md).
- `DBA_HIST_SYSMETRIC_SUMMARY` carries I/O and CPU metrics as averages over the
  AWR cycle — which matters for interpretation →
  [Measuring system load](measuring-system-load.md).
- `DBA_HIST_SEG_STAT` receives the segment statistics at each snapshot; for a
  finer resolution you have to measure yourself → [Segment statistics](segment-statistics.md).
- `DBA_HIST_LATCH` carries the latch statistics → [Result cache](result-cache.md).
- `DBA_HIST_REPORTS` keeps SQL Monitor reports beyond their short life from
  12.1 onwards → [SQL Monitor](sql-monitor.md).

## From the talks

([Talks on Panorama and the Panorama Sampler](../sources/talks-panorama-and-sampler.md).) Oracle's line of instruments, as the 2025 and
2026 talks put it: the dynamic performance views show the current state but no
history; Statspack has offered rudimentary snapshots since 8i; AWR and ASH,
since 10g, are "tailor-made for troubleshooting and forensics" — and require
Enterprise Edition plus the Diagnostics Pack.

A warning from the 2024 talk: the AWR views **can be queried without a licence,
and querying them is the licence violation**. Nothing technical stops it — hence
Panorama's own guard ([Pack licence filter](../development/pack-license-filter.md)).

Two details: `DBA_Hist_Filestatxs` is **no longer filled by AWR from 18c** (I/O
history has two other AWR sources); and AWR did not store access and filter
predicates of execution plans up to release 21, which the
[Panorama Sampler](panorama-sampler.md) does.

## From the website

([Panorama's website on GitHub Pages](../sources/rammpeter-github-io.md).) The usage guide gives the retention of the persistent
ASH data as the AWR retention — **"default=7 days, recommended > 30 days"** —
and the snapshot interval as hourly by default. Where AWR data is read in
Panorama: [SQL area](sql-area.md) (historic SQL), [Session waits](session-waits.md) (ASH),
[Segment statistics](segment-statistics.md), [Redo logs](redo-logs.md); Oracle's own report on it is reached
through [Genuine Oracle reports](genuine-oracle-reports.md). All views are listed in
[Panorama menu overview](panorama-menu-overview.md).

## Relationships

- Complements [ASH](ash.md): AWR aggregates over intervals, ASH keeps individual
  samples of active sessions.
- Its use requires a licence — see [Management pack licensing](management-pack-licensing.md).
- Evaluated by [Panorama](panorama.md) in the historical analyses; without a licence
  [Panorama Sampler](panorama-sampler.md) takes its place.

## Open questions

- Which AWR views are the most productive in practice?
- How do AWR data behave in RAC environments (evaluation across instances)?
- What exactly does a snapshot contain, and what is the default interval? Not
  covered by any ingested source.

## Sources

- [Blog series on execution plans and the optimizer](../sources/blog-execution-plans.md)
- [Blog series on system load and monitoring](../sources/blog-system-load.md)
- [Talks on Panorama and the Panorama Sampler](../sources/talks-panorama-and-sampler.md)
- [Panorama's website on GitHub Pages](../sources/rammpeter-github-io.md)
