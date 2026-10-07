---
title: Session waits
type: entity
subtype: component
status: draft
tags: [panorama, menu, sessions, ash]
created: 2026-10-05
updated: 2026-10-05
sources: [rammpeter.github.io.md, rammpeter.github.io/Oracle_performance_analysis_with_Panorama.html, rammpeter.github.io/panorama_content_generated.html]
---

# Session waits

The submenu "Analyses / statistics" / "Session-Waits" of [Panorama](panorama.md): what
active sessions are waiting on, now and in the past. Its "Historic" entry is
Panorama's main view onto [ASH](ash.md).

## The four entries

([Panorama's website on GitHub Pages](../sources/rammpeter-github-io.md), menu overview.)

| Entry | Purpose as stated |
|---|---|
| Current | "All current session waits" |
| Historic | "Prepared active session history from DBA_Hist_Active_Sess_History" |
| CPU-Usage / DB-Time | Historic CPU usage and DB time from ASH; shows "the difference between real CPU-usage and waiting for CPU if you don't have Resource Manager activated" |
| Long-term trend | "Long-term trend recording of session waits" → [Long-term trend analysis](long-term-trend-analysis.md) |

## Current

(Usage guide 2.1.2.) An overview of the wait states of the currently active
sessions **and** of the concurrency between them: besides the wait events, the
blocker/waiter relationships are listed hierarchically, taken from `gv$Session`.

This is one of **two** routes to current blocking locks — the other, "DBA
general" / "DB-Locks" / "Current", reads `gv$Lock`. The guide states that certain
special blocking situations are shown by only one of the two
→ [Blocking locks](blocking-locks.md).

## Historic — the ASH analysis

(Usage guide 2.1.3.) The mechanics the view rests on:

- ASH records context information of active sessions **every second** in SGA
  memory (`gv$Active_Session_History`), kept at least until the next AWR
  snapshot or as long as SGA memory allows.
- At each AWR snapshot (default hourly) the volatile data is copied to
  `DBA_Hist_Active_Sess_History` — **only every tenth sample**.
- That persistent data is kept for the AWR retention: "default=7 days,
  recommended > 30 days".
- **Panorama combines both sources**: the one-second samples as long as they are
  available, the ten-second samples otherwise.

Starting an analysis requires a **time period** and an **initial grouping
criterion**. From the grouped result:

- **Time course as a diagram** via the context menu: the top 10 of the grouping
  criterion as separate curves, the rest in one curve; condensed to 60 seconds,
  10 seconds or 1 second.
- **Drill-down** into the selected row by splitting it along another criterion —
  a click into the corresponding column.
- **Changing the perspective** from wait time to the SQL involved, the data
  structures accessed, the PL/SQL objects executed, and so on.
- **The individual samples** behind the current filters — "smallest grain of
  information" — by a click in the column "Samples".

The same view is reached with predefined filters from many detail views (session,
SQL, …).

## CPU-Usage / DB-Time

The menu text explains what to read from it: a gap between CPU actually used and
time spent waiting for CPU means "you have more sessions waiting for CPU than
your system's number of CPU-cores" — visible this way if the Resource Manager is
not active.

> Conclusion: with the Resource Manager active, waiting for CPU shows up as its
> own wait event; without it, a session queued for a core is simply recorded as
> "on CPU". This entry makes the hidden queue visible by comparison. The basic
> measure of load is described in [Measuring system load](measuring-system-load.md).

## Licence

"Historic" and "CPU-Usage / DB-Time" read ASH and therefore need the Diagnostics
Pack — or [Panorama Sampler](panorama-sampler.md), whose ASH replacement is evaluated in the same
views with the limits listed there ([Management pack licensing](management-pack-licensing.md)).

## Relationships

- Listed in [Panorama menu overview](panorama-menu-overview.md); second pillar-one view next to
  [Session list](session-list.md).
- What ASH cannot show: [ASH](ash.md) (idle waits), [Short-lived sessions](short-lived-sessions.md).
- Derived analyses: [Blocking locks](blocking-locks.md), [TEMP usage](temp-usage.md),
  [Estimating network latency from ASH](network-latency-from-ash.md).

## Open questions

- Which grouping criteria are offered is not listed in the source.
- The guide's "recommended > 30 days" retention is given without a reason there;
  the argument for long retention is made in [AWR](awr.md) and
  [Long-term trend analysis](long-term-trend-analysis.md).

## Sources

- [Panorama's website on GitHub Pages](../sources/rammpeter-github-io.md)
