---
title: Redo logs
type: concept
status: draft
tags: [redo, storage, oracle]
created: 2026-10-01
updated: 2026-10-05
sources: [blog.md, posts/, speakerdeck.md, speakerdeck/, rammpeter.github.io.md, rammpeter.github.io/]
---

# Redo logs

Too few redo log groups will freeze a database — and three groups are the DBCA
default. Accordingly, according to [Blog series on storage, tablespaces and redo](../sources/blog-storage.md) (2017-02-25), you find "many
DB instances in production with only 3 redo log groups".

## The damage pattern

All commit operations are suspended for seconds or even minutes. In production
that means: services unavailable, timeout exceptions, considerably reduced
throughput.

## The mechanism

The redo logs are a ring buffer. For a log switch to succeed, the **next** group
must satisfy two conditions:

| Condition | Signal |
|---|---|
| fully processed by the DB writer | `Status = 'INACTIVE'` |
| fully processed by the archiver | `Archived = 'YES'` |

If the next group is still `ACTIVE` or not yet archived, **the log switch waits —
and with it all write operations on the redo log, that is, all commits**.

Two reasons for that:

- The **DB writer** cannot process the other groups in time — depending on the
  speed of the I/O system and the amount of redo per unit of time.
- The **archiver** does not copy fast enough, particularly with active Data Guard
  or a standby database.

## The rules of thumb

- Size the redo log files so that the interval between two log switches is
  **always more than one minute**.
- Create enough groups so that under **all** circumstances one or two are always
  ready (`Status = INACTIVE` **and** `Archived = YES`).

> The actual purpose of additional groups is therefore not space but **buffer**:
> the database is put in a position to absorb short overload phases in which the
> processes generate more DML load than the DB writer and archiver can process
> simultaneously.

Additionally to be considered: whether the behaviour matches the requirement for
the maximum recovery time (`FAST_START_MTTR_TARGET`), and whether to speed up the
DB writer or archiver themselves — via more processes, for instance.

## Proving that it happened

Three independent trails:

**1. Alert log** — search for `cannot allocate new log` and
`Checkpoint not complete`.

**2. `DBA_HIST_LOG`** — status and archived flag at the times of the AWR
snapshots. What has to be counted are the active and the not-yet-archived groups.
The source supplies a query for this that derives the **number of log switches**
per snapshot via `LAG` on `MAX(Sequence#)` and computes the average interval from
it — which allows searching for times below 60 seconds.

The interpretation pattern from the author's example: the archiver was fast
enough (one group `ARCHIVED`), the DB writer was not — for hours two groups were
`ACTIVE` and one `CURRENT`. Exactly the situation in which no log switch can
succeed.

**3. [ASH](ash.md)** — search for the wait event
`log file switch (checkpoint incomplete)`; it shows the sessions waiting for the
switch. In the example up to ten simultaneously.

In [Panorama](panorama.md): "DBA general" / "Redo logs" / "Historic" for `DBA_HIST_LOG`,
"Analyses / statistics" / "Session waits" / "Historic" for the wait event.

## From the 2024 talk

([Talks on Panorama and the Panorama Sampler](../sources/talks-panorama-and-sampler.md), slides 36–37.) Besides the three groups, the
default **size of 200 MB** "can be much too small"; the optimisation target given
is **more than 10 seconds between log switches**. In the historic view
("DBA general" / "Redologs" / "Historic") the number of groups in state current
plus active should normally never reach the number of available groups; within
an AWR cycle a shortage can hide, so cross-check the alert log for "cannot
allocate new log".

## From the usage guide and the menu

([Panorama's website on GitHub Pages](../sources/rammpeter-github-io.md).) The submenu "DBA general" / "Redo-Logs" has **three**
entries: "Current" (from `gv$Log`), "Historic from gv$Log_History" (detailed) and
"Historic from AWR". The guide (4.3) still speaks of one "Historical" entry; it
describes the AWR one — usage per snapshot with the number of log switches and
the number of log files still active and not yet archived.

The guide repeats the rule in its sharpest form: the number of active or not yet
archived log files "should never reach the number of existing log file groups"
on a production system, and calls the risk **often latent**, because databases
are created with three groups by default and this is frequently not adapted —
with rising write load a temporary freeze "is preprogrammed".

> The entry on `gv$Log_History` needs neither AWR nor the sampler. Whether it
> shows the shortage itself or only the switch frequency is not stated.

## Relationships

- The trail via wait events goes through [ASH](ash.md).
- Historical values from [AWR](awr.md) (`DBA_HIST_LOG`).
- Related to [Measuring system load](measuring-system-load.md): the amount of redo per unit of time is a
  load metric.

## Open questions

- How many groups are "enough"? The source says "one or two ready under all
  circumstances" but names no concrete number.
- What interaction is there between log file size and
  `FAST_START_MTTR_TARGET`? The source names the connection but does not develop
  it.

## Sources

- [Blog series on storage, tablespaces and redo](../sources/blog-storage.md)
- [Talks on Panorama and the Panorama Sampler](../sources/talks-panorama-and-sampler.md)
- [Panorama's website on GitHub Pages](../sources/rammpeter-github-io.md)
