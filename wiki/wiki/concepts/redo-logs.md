---
title: Redo logs
type: concept
status: draft
tags: [redo, storage, oracle]
created: 2026-10-01
updated: 2026-10-02
sources: [blog.md, posts/]
---

# Redo logs

Too few redo log groups will freeze a database — and three groups are the DBCA
default. Accordingly, according to [[blog-storage]] (2017-02-25), you find "many
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

**3. [[ash]]** — search for the wait event
`log file switch (checkpoint incomplete)`; it shows the sessions waiting for the
switch. In the example up to ten simultaneously.

In [[panorama]]: "DBA general" / "Redo logs" / "Historic" for `DBA_HIST_LOG`,
"Analyses / statistics" / "Session waits" / "Historic" for the wait event.

## Relationships

- The trail via wait events goes through [[ash]].
- Historical values from [[awr]] (`DBA_HIST_LOG`).
- Related to [[measuring-system-load]]: the amount of redo per unit of time is a
  load metric.

## Open questions

- How many groups are "enough"? The source says "one or two ready under all
  circumstances" but names no concrete number.
- What interaction is there between log file size and
  `FAST_START_MTTR_TARGET`? The source names the connection but does not develop
  it.

## Sources

- [[blog-storage]]
