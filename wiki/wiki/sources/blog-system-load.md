---
title: Blog series on system load and monitoring
type: source
status: maintained
tags: [ash, system-load, oracle]
created: 2026-10-01
updated: 2026-10-02
sources: [blog.md, posts/]
---

# Blog series on system load and monitoring

Seven posts from [[rammpeter-blog]] between 2012 and 2026 — the oldest and the
newest of the blog — on the question of how loaded a system is: now,
retrospectively, and across years.

## The posts

| Date | Title | Focus |
|---|---|---|
| 2012-05-14 | Measure average system load on oracle database instance | [[measuring-system-load]] |
| 2012-05-15 | Measure average I/O-load and CPU-usage on Oracle database instance | [[measuring-system-load]] |
| 2017-04-14 | Does Active Session History always allows you to reconstruct your active sessions behaviour? | [[ash]] |
| 2021-06-12 | Real-time monitoring dashboard in Panorama | [[panorama]] |
| 2022-06-10 | Long-term trend analysis of Oracle database workload | [[long-term-trend-analysis]] |
| 2024-09-29 | Evaluate current segment statistics prior to next AWR snapshot | [[segment-statistics]] |
| 2026-09-16 | Show long running operations from GV$Session_LongOps including the name of the accessed partitions | [[long-operations]] |

## Key points

**Peak and average at the same time.** The two oldest posts supply the basic
measure: active sessions and, of those, the ones on CPU — each as a peak value,
as an average over the period and as the highest one-minute and one-hour
average. The smoothing is the point here, not any single value (2012)
→ [[measuring-system-load]].

**ASH has a systematic blind spot.** A session that is busy for an hour can
appear in ASH as mostly idle: **ASH does not record wait states of the wait class
"idle"** — and `V$SQL.ELAPSED_TIME` does not count them either. With this the
author explicitly revises his own earlier assumption (2017-04-14) → [[ash]].

**Long-term trends only work condensed.** ASH is retained for 7 days by default,
usually about 30 days in production. For hardware planning across years only
condensing remains: [[panorama-sampler]] stores summaries per hour up to per day
— **about 1/1000** of the ASH volume at daily resolution. Backed by a figure:
four years of a heavily used 10 TB system in roughly **55 MB** (2022-06-10)
→ [[long-term-trend-analysis]].

**Segment statistics can be measured without an AWR snapshot.**
`GV$SEGMENT_STATISTICS` only carries totals since instance start. The post of
2024-09-29 derives a delta over *x* seconds from it — and encapsulates the whole
thing in **a single SELECT** using `WITH FUNCTION`, so that nothing has to be
installed on the target database → [[segment-statistics]].

**Long operations reveal the partition.** Via `GV$SESSION.ROW_WAIT_OBJ#` you can
determine which object — and therefore which partition — a long-running scan is
currently reading (2026-09-16) → [[long-operations]].

## Impact on the wiki

New: [[measuring-system-load]], [[long-term-trend-analysis]],
[[segment-statistics]], [[long-operations]].

Substantially extended: [[ash]] — the post of 2017-04-14 supplies the single most
important limitation of this data source. Added to: [[panorama]] (dashboard),
[[panorama-sampler]] (long-term data).

## Notes on the evidence

**An explicitly revised assumption.** The post of 2017-04-14 opens with the
question whether ASH really records everything and answers: *"I thought so
before, but it isn't."* That is not an aside but the core of the post — recorded
in [[ash]] as a limitation, not as a footnote.

**A figure with its basis disclosed.** The 55 MB for four years apply to a
specific, "frequently used" 10 TB system at daily resolution. Carried over into
[[long-term-trend-analysis]] with those conditions included.

**A validity check inside the SQL itself.** The post of 2026-09-16 contains a
column `Object_Belongs_To_Target_Table` that checks whether the partition
information obtained via `ROW_WAIT_OBJ#` belongs to the target object at all —
the author distrusts his own method in exactly the right place.

**Outside inspiration named:** the author credits Matthias Rogel for the long ops
logic.

## Source files

`raw/posts/01-*`, `02-*`, `22-*`, `48-*`, `49-*`, `61-*`, `74-*`
