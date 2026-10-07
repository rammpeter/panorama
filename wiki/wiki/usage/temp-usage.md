---
title: TEMP usage
type: concept
status: draft
tags: [storage, ash, oracle]
created: 2026-10-01
updated: 2026-10-04
sources: [blog.md, posts/, speakerdeck.md, speakerdeck/]
---

# TEMP usage

If `ORA-1652: unable to extend temp segment` appears in the alert log, the
session reported is often **not** the guilty one.

## Two possible causes

([Blog series on storage, tablespaces and redo](../sources/blog-storage.md), 2016-03-23)

1. The session that receives the error has itself allocated a lot of TEMP and has
   reached the end of the available space.
2. **Other** sessions successfully allocated large amounts — and this session,
   with only a small requirement, gets the error.

> The second case is the insidious one: the error hits whoever chance hits. The
> question is therefore not "what did this session do?" but "who was occupying
> the space at that moment?"

## The route to the answer

In [Panorama](panorama.md) via "Schema / Storage" / "Temp usage" / "Historic":

1. Choose the period and time unit, sort by "Max. TEMP allocated" and display the
   column as a chart — that locates the peak in time.
2. From the peak minute, go via the "Total time waited" column into the [ASH](ash.md)
   evaluation of that minute, grouped by RAC instance to begin with.
3. Via "Session / Sn." descend to session level for the instance with the highest
   "Max. temp", remove the instance filter if necessary and sort descending by
   "Max. temp".

That leaves the sessions that occupied the space on screen — together with their
execution context, SQL, wait events and affected objects.

**A pitfall with parallel query:** "Max. temp" only shows the **maximum across
coordinator and slaves**, not their sum. For the actual allocation you have to
look in the "Parallel query" column at what this coordinator's slaves consumed.

## What the talk adds

([Talks on Active Session History and TEMP analysis](../sources/talks-ash-and-temp.md), DOAG 2017.)

**A third cause**, named but not treated: unused TEMP space allocated on
*another RAC instance*.

**Where TEMP history can be read:**

| Source | Granularity |
|---|---|
| `DBA_Hist_Active_Sess_History` / `GV$Active_Session_History`, column `Temp_Space_Allocated` | per session, every 10 seconds / every second |
| `DBA_Hist_SysMetric_Summary` / `GV$SysMetric_History`, metric "Temp Space Used" | per instance, per AWR snapshot / per minute for the last hour |
| `DBA_Hist_Sysstat`, statistic "temp space allocated (bytes)" | per instance and AWR snapshot |
| `GV$SORT_SEGMENT`, `GV$TEMPSEG_USAGE` | current state only |

In the first screen Panorama shows *allocated* as the value at the end of the AWR
cycle and *used* as the maximum within it.

**The gap, and how the query bridges it.** A session that holds TEMP while
inactive — or active in wait class Idle — is not sampled by [ASH](ash.md), so its
allocation is missing from the sum at that instant. Panorama's query therefore
takes, for each sample time, the maximum each session showed within **±20
seconds** ("floating") in addition to the exact value. The talk's own
assessment: this helps to count temporarily inactive sessions and so to
reconstruct reality *approximately*.

> Conclusion: the per-session history is a lower bound that the floating window
> raises towards the truth; the per-instance metrics are exact but anonymous.
> Reading both side by side — exact total, approximate attribution — is the
> honest use.

## Relationships

- The data foundation is [ASH](ash.md) — and therefore
  [Management pack licensing](management-pack-licensing.md) or [Panorama Sampler](panorama-sampler.md).
- The same basic problem in the permanent tablespace:
  [Tablespace fragmentation](tablespace-fragmentation.md).
- Parallel query as a disturbance to the measurement:
  [Parallel execution](parallel-execution.md).

## Open questions

- Why does "Max. temp" show the maximum rather than the sum across the parallel
  query processes? The source states it but does not explain it.
- Can TEMP allocation also be limited *preventively*, per user or resource group,
  say? Not covered in the post.

## Sources

- [Blog series on storage, tablespaces and redo](../sources/blog-storage.md)
- [Talks on Active Session History and TEMP analysis](../sources/talks-ash-and-temp.md)
