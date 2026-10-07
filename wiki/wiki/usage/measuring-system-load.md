---
title: Measuring system load
type: concept
status: draft
tags: [system-load, ash, awr, oracle]
created: 2026-10-01
updated: 2026-10-02
sources: [blog.md, posts/]
---

# Measuring system load

The two oldest posts of the blog (2012) supply the basic measure: how heavily
loaded is this system — and in a way that makes both the peaks and the sustained
load visible.

## Active sessions

([Blog series on system load and monitoring](../sources/blog-system-load.md), 2012-05-14) Two quantities are measured from
`DBA_HIST_ACTIVE_SESS_HISTORY`, per instance — so separately with RAC:

- **the total number of active database sessions**
- of those, the number of sessions **on CPU** (`Session_State = 'ON CPU'`, that
  is, with no other wait event)

Each reported as:

| Metric | Meaning |
|---|---|
| peak value | the highest individual value ever measured, with timestamp |
| average over the period | the sustained load |
| highest one-minute average | the strongest short phase |
| highest one-hour average | the strongest longer phase |

> The gradation is the actual idea: a peak value alone says little, an average
> over days conceals everything. The highest one-minute and one-hour averages in
> between show whether a peak was an outlier or a state.

Implemented via window functions (`AVG(…) OVER (PARTITION BY Instance_Number,
TRUNC(Sample_Time, 'MI'))` and `'HH24'` respectively) and
`KEEP (DENSE_RANK LAST ORDER BY …)`, to deliver the timestamp along with each
maximum.

**One telling detail:** the query explicitly excludes `PX Deq Credit: send blkd`
as an idle event. Five years later that same event is the subject of the post
about the blind spot of [ASH](ash.md).

## I/O and CPU

([Blog series on system load and monitoring](../sources/blog-system-load.md), 2012-05-15) From `DBA_HIST_SYSMETRIC_SUMMARY`, that is, on
the basis of the averages within an AWR cycle:

- `Physical Read/Write Total Bytes Per Sec` — transfer volume
- `Physical Read/Write IO Requests Per Sec` — number of requests
- `Host CPU Utilization (%)` — utilisation of the host
- `CPU Usage Per Sec` — CPU cores occupied by the database

Here too per instance, with peak value and timestamp.

> Important for interpretation: the values are **averages over the AWR cycle**.
> The query therefore reports the cycle length in minutes along with each maximum
> — a peak averaged over 60 minutes is something different from one over 5
> minutes.

Separating transfer volume from request count is the actual message here: many
small I/Os load a disk system differently from a few large ones — exactly the
case that was the occasion for [Sampling session statistics yourself](sampling-session-statistics.md).

## Relationships

- Data foundation: [AWR](awr.md) and [ASH](ash.md).
- For periods beyond the AWR retention: [Long-term trend analysis](long-term-trend-analysis.md).
- Finer than the AWR cycle, without waiting for the next snapshot:
  [Segment statistics](segment-statistics.md).
- Long operations currently running: [Long operations](long-operations.md).

## Open questions

- Which values count as "too high"? The posts supply the measurement, not
  thresholds.
- Both queries are from 2012 and use a fixed period (`SYSTIMESTAMP - 4` and
  `- 7` respectively). Whether the views and metric names used have remained
  stable across all later releases is not evidenced.

## Sources

- [Blog series on system load and monitoring](../sources/blog-system-load.md)
