---
title: Short-lived sessions
type: concept
status: draft
tags: [core, session, oracle]
created: 2026-10-01
updated: 2026-10-02
sources: [blog.md, posts/]
---

# Short-lived sessions

Applications that build up and tear down a session of their own for every single
database activity — inside a loop body or when polling. A "generally assessed
poor technique" whose price is rarely quantified.

## The price, measured

[[blog-sessions-and-connections]] (2020-10-12) closes that gap. The starting
point is an observation that explains why the problem so often goes unnoticed:

> "The internal recording of database activity (AWR/ASH) has no answer because
> establishing the DB connection is not a SQL activity."

Establishing a connection is not SQL — so it appears neither in [[ash]] nor in
[[awr]]. It was therefore measured via system load:

**Setup:** an idle instance on a host with 4 older CPU cores (Intel Xeon E312xx,
2.6 GHz), an external SQL*Plus client executing a single
`SELECT SYSTIMESTAMP FROM DUAL` per session, 6 threads each creating one
connection per second.

| State | CPU load across 4 cores |
|---|---|
| instance idle | 0.22 % |
| 6 threads, 1 connection/s each | 6.09 % (+ 1.07 % I/O wait) |

From that: 5.87 % of 4 cores for 6 threads, that is 23.48 % of one core for 6
threads — **roughly 4 % of a CPU core per thread**.

> **The number to remember:** building up and tearing down a dedicated Oracle
> session once per second costs about 4 % of a CPU core of the database server.
>
> Placement: the figure comes from a concrete measurement on specific hardware
> explicitly described as "older". As an order of magnitude for the decision
> "is the rework worth it?" it is usable; as a calculation input it is not.

**The remedy:** hold the connection for the lifetime of the application instance
or use connection pooling on the client or server side.

## Finding the culprits

Four methods from [[blog-sessions-and-connections]] (2017-03-22), from the most
convenient to the most accurate:

**1. Audit trail.** If auditing of logon/logoff is active, `DBA_AUDIT_TRAIL`
shows the machine, the database user and the OS user. In [[panorama]] under
"DBA general" / "Audit Trail": filter on `Action = LOGON`, group by minute and
display as a chart — in the author's example this attributes 106 logons per
minute to one culprit. See [[audit-trail]].

**2. Currently running short sessions.** A PL/SQL loop queries `GV$SESSION` at
very short intervals for sessions with a `Logon_Time` within the last few
seconds. Two hints from the source: `AudSID != 0` filters out incomplete
connects, and the `Process` column shows the client process ID — **except for
JDBC sessions, which always carry the invented process ID 1234**.

**3. Via ASH.** Sessions with only a single sample record in
`GV$ACTIVE_SESSION_HISTORY`. The author immediately qualifies the method
himself: *"for this purpose a sample cycle of one second is much too large in
most cases."* → [[ash]]

**4. A package of its own.** `Detect_Short_Running_Sessions` compares
`GV$SESSION` snapshots at millisecond intervals and writes vanished sessions into
a table `DSRS_RESULT` — a shadow copy of the sessions that live too briefly to be
captured any other way. Parameters: observation duration, interval between
snapshots (default 100 ms), maximum age of the captured session, grouping
interval.

## When the client is JDBC

Because of the invented process ID 1234, the causing process can only be found on
the client operating system. The post shows this for Linux via `lsof`: first
count the process IDs with open Oracle connections, then sample repeatedly over a
few seconds — the connections at the bottom of the frequency list are the
short-lived ones.

## Relationships

- Attribution to a process requires [[session-context]].
- Data source for method 1: [[audit-trail]].
- The limits of method 3 are the limits of [[ash]].
- A related measurement problem: [[network-latency-from-ash]] — there too a poor
  architecture is simultaneously the measurement opportunity.

## Open questions

- How does the 4 % figure behave on current hardware and with shared server
  instead of dedicated processes?
- What does establishing a connection cost *with* a connection pool by
  comparison — that is, how much does the rework actually save?
- `DBMS_LOCK.SLEEP` in the scripts is to be replaced by `DBMS_SESSION.SLEEP`
  from 18c; the source notes this but has not converted the scripts.

## Sources

- [[blog-sessions-and-connections]]
