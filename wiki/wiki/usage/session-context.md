---
title: Session context
type: concept
status: draft
tags: [session, oracle]
created: 2026-10-01
updated: 2026-10-05
sources: [blog.md, posts/, speakerdeck.md, speakerdeck/, rammpeter.github.io.md, rammpeter.github.io/]
---

# Session context

Module and action information in `V$SESSION`, set via
`DBMS_APPLICATION_INFO.SET_MODULE`. Without it, any later analysis is blind to
the question of *which process* caused an activity.

## Why it matters

> "Setting module and action info via DBMS_Application_Info.Set_Module gives
> valuable context info in V$Session, Active Session History etc."
> — [Blog series on sessions, connections and the network](../sources/blog-sessions-and-connections.md), 2014-07-09

The context travels into [ASH](ash.md) and is later the only anchor by which a wait
time can be attributed to a business process. It is also the criterion by which
a trace can be narrowed to one application → [SQL trace](sql-trace.md).

## The problem with SQL*Plus jobs

For jobs that execute SQL via SQL*Plus, the information wanted is usually the
**name of the calling process**. Hoping that every job calls `SET_MODULE` of its
own accord is unrealistic.

The solution from the source: a **`login.sql`** that is executed automatically
whenever a SQL*Plus process starts. For that, the environment variable `SQLPATH`
has to point to the directory of that file — then *every* SQL*Plus invocation
sets its context itself.

The mechanism in the script:

1. `SYS_CONTEXT('USERENV','SESSIONID')` supplies a unique identifier for a unique
   temporary file name.
2. Via `HOST ps` the **parent process** of SQL*Plus is determined — that is, the
   calling job — and an `EXEC DBMS_Application_Info.Set_Module(...)` is written
   into the temporary file using `awk`.
3. The file is executed with `START` and deleted afterwards.

Framed by `SET TERMOUT OFF` / `ON`, so that the job notices nothing of it.

> The core of the trick: the context is enforced **from outside**, not requested
> from the application. That is exactly why it works for legacy scripts nobody
> touches any more.

## The pooling argument

([Talks on Active Session History and TEMP analysis](../sources/talks-ash-and-temp.md), 2016; repeated in the 2024 talk.) With an application
server and session pooling, each short transaction takes an arbitrary session
from the pool, and a process that scales in parallel uses a varying number of
them. No session "belongs" to a process. The question that always comes —
"process XY ran three times as long last night, why?" — can then only be answered
if module and action were set at the start of each transaction: they are sampled
into [ASH](ash.md) and recorded in other tracks of the database, and allow the
activity to be assigned to the triggering process afterwards.

## From the usage guide

([Panorama's website on GitHub Pages](../sources/rammpeter-github-io.md), usage guide 5.1 — the only written section of its
chapter on application design.) Module and action hold **64 characters each**;
they are recorded "in various histories (including in ASH and SQL statistics)".
The advice on *where* to set them: anchor the call **deep in the technical
infrastructure** of the application, for instance at the beginning of every
transaction or request, so that tagging is complete. With only sporadic setting
on pooled connections, later activity stays assigned "to a random predecessor
activity of this session" — the pooling argument above, in the author's own
summary.

The tags are what the module filters in [Session list](session-list.md) and the grouping
criteria in [Session waits](session-waits.md) work on.

## Relationships

- Makes [Short-lived sessions](short-lived-sessions.md) attributable.
- Is the filter criterion for [SQL trace](sql-trace.md).
- Travels into [ASH](ash.md) and becomes an analysis dimension there.
- Its results give context to [Sampling session statistics yourself](sampling-session-statistics.md).
- The same mechanism (automation on connecting) in a different form:
  [LOGON trigger](logon-trigger.md).

## Open questions

- The script relies on Unix tools (`ps`, `awk`, `rm`). How do you solve it under
  Windows?
- What length may module and action have, and what happens on truncation? The
  source truncates to 48 characters but does not explain the limit.

## Sources

- [Blog series on sessions, connections and the network](../sources/blog-sessions-and-connections.md)
- [Talks on Active Session History and TEMP analysis](../sources/talks-ash-and-temp.md)
- [Panorama's website on GitHub Pages](../sources/rammpeter-github-io.md)
