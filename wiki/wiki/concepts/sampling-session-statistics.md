---
title: Sampling session statistics yourself
type: concept
status: draft
tags: [session, sampling, oracle]
created: 2026-10-01
updated: 2026-10-02
sources: [blog.md, posts/]
---

# Sampling session statistics yourself

A gap Oracle leaves open:

> "In current version of Oracle database there's no way to breakdown historic
> statistic values to sessions if session has already terminated."
> — [[blog-sessions-and-connections]], 2014-06-03

The values from `GV$SESSTAT` are only available for **living** sessions. Whoever
wants to know hours later which session produced the load finds nothing — the
culprits ended long ago.

## The occasion

The concrete case from the source: a huge number of transactions produced masses
of small write I/Os and hit the limits of the physical disks. To clarify the
cause, the causing process had to be named — but the examination could only take
place hours later.

## The procedure

An anonymous PL/SQL block collects on two cycles:

- **Memory cycle** (default 10 s): join `GV$SESSTAT` with `GV$SESSION` and hold
  the values for one statistic in memory, indexed by
  `Inst_ID:SID:Serial#:Statistic#`.
- **Write cycle** (default 900 s): write the **difference** from the last saved
  state into a table. Zero values are suppressed, and the first cycle is skipped
  because it has no predecessor.

Driven by `v$StatName` — `user commits` in the example — with a minimum value
below which a session is not captured.

**The abort control via a semaphore** is the elegant part: a control table with
one record that the sampler re-locks after every commit via
`SELECT … FOR UPDATE NOWAIT`. To stop the sampler, you lock the record from
outside (`SELECT * FROM SessMon_Semaphore FOR UPDATE`) — the sampler fails on its
next attempt and terminates. No signal, no file, no job management needed.

The block needs an `EXECUTE` privilege on `DBMS_LOCK` in order to sleep between
cycles rather than poll — explicitly to reduce CPU consumption.

## The evaluation

The result is sorted by consumption and enriched with context from
`DBA_HIST_ACTIVE_SESS_HISTORY` — module, action, user, program, machine. The join
runs via `Inst_ID`, `SID` and `Serial#`; that is precisely why the log table
keeps those three columns.

> This closes the circle: the self-captured numbers get their context from
> [[ash]] — and [[session-context]] is the prerequisite for that context to mean
> anything.

## Relationships

- The same principle, built into Panorama: [[panorama-sampler]].
- Attributing the results relies on [[ash]] and [[session-context]].
- A related problem: [[short-lived-sessions]] — there too the author resorts to
  sampling of his own, because the built-in means are too coarse.
- The I/O pattern that caused the case: [[measuring-system-load]] separates
  transfer volume from request count for exactly this reason.

## Open questions

- The approach captures **one** statistic per run. How does it scale for several?
- What overhead does accessing `GV$SESSTAT` on a 10-second cycle cause on a
  system with many sessions?
- Does [[panorama-sampler]] now answer the same question off the shelf? The
  relationship between the two is not evidenced.

## Sources

- [[blog-sessions-and-connections]]
