---
title: Blocking locks
type: concept
status: draft
tags: [core, locks, oracle]
created: 2026-10-01
updated: 2026-10-05
sources: [blog.md, posts/, speakerdeck.md, speakerdeck/, rammpeter.github.io.md, rammpeter.github.io/]
---

# Blocking locks

When sessions block each other, a hierarchy forms. The decisive question is never
"who is waiting?" but **"who is the root?"** — because only resolving that one
frees the whole chain.

## The current situation

In [Panorama](panorama.md) under "DBA general" / "DB locks" / "Current", button "Blocking
DML-Locks" ([Blog series on locks and serialisation](../sources/blog-locks.md), 2016-06-03). Three sessions are reported per lock:

- the **waiting** session,
- the **blocking** session,
- the **root session** that causes the hierarchy.

If the blocking session is also the root, it is marked **orange**. The practical
meaning: that is precisely the problem you have to resolve — probably by killing
the session — in order to free the entire hierarchy.

From there onwards to: details of the blocking and waiting session, the waiting
SQL, and other sessions trying to lock the same ID1/ID2 combination.

**Down to the individual row:** a click on file, block and `row#` computes the
blocking ROWID; a click on the ROWID shows the primary key columns and value of
the blocking row.

## The situation in the past

The basis is [ASH](ash.md): from the recorded session activity, lock constellations can
be reconstructed retrospectively, including the root session
([Blog series on locks and serialisation](../sources/blog-locks.md), 2016-06-03 and 2020-10-06). Menu "DBA general" / "DB-Locks" /
"Blocking locks historic from ASH".

**Prerequisite:** Enterprise Edition and the Diagnostics Pack — or the
[Panorama Sampler](panorama-sampler.md), which Panorama evaluates *transparently in the same way*.
See [Management pack licensing](management-pack-licensing.md).

### Three directions

**1. Top-down via the dependency tree** ("Blocking locks session dependency
tree"). Delivers all detected root sessions of the period, sorted by the wait
time of all directly or indirectly blocked sessions. For each root session, the
number of directly blocked sessions and the total number of sessions blocked in
the hierarchy are provided as links.

**2. Top-down via wait event pairs** (new in the 2020-10-06 version). Groups
blocking and blocked sessions by their wait events and shows which wait states
depend on which.

> The benefit according to the source: this view remains analysable even when
> **very many** sessions are involved — where the dependency tree becomes
> unmanageable. With RAC the wait events can be shown per instance, to identify
> contention between the nodes.

**3. Bottom-up** — from a single ASH record of a blocked session up the
dependency tree to the root, via the "Thread" button.

### Deadlocks

In doing so a **cross dependency** occasionally shows up, which the database
later resolves itself with "deadlock detected". The last session before the cycle
is marked **"DEADLOCK"** in this presentation.

## Oracle's emergency brake

For the worst case, before an instance is restarted
([Blog series on locks and serialisation](../sources/blog-locks.md), 2016-06-03):

```
sqlplus / as sysdba
> oradebug setmypid
> oradebug hanganalyze 12
```

Captures the hanging state of the database in a trace file — so that the cause is
still investigable after the restart.

## Two routes to the current locks, one more to the past

([Panorama's website on GitHub Pages](../sources/rammpeter-github-io.md), usage guide 2.1.4.) "DBA general" / "DB-Locks" /
"Current" offers four displays: all current DML locks, all **blocking DML
locks**, all **blocking DDL locks**, and **two-phase commits that have not
completed** (for instance over a database link).

For current blocking DML locks there are **two analysis paths, and certain
special blocking situations are shown by only one of them**:

- **via `gv$Lock`** — the button "Blocking DML Locks" described above: the
  hierarchical blocker/waiter relationships, starting from the session that
  triggers the cascade, built from waiting lock requests.
- **via `gv$Session`** — "Analyses / statistics" / "Session-Waits" / "Current":
  next to the wait events of the active sessions, the blocker/waiter
  relationships are listed hierarchically from the session view
  → [Session waits](session-waits.md).

> Conclusion: if one view shows no blocker although sessions are evidently
> waiting, look at the other before concluding there is none. The guide does not
> say which situations fall through which view.

For the past there is a second entry besides ASH: **"Blocking locks historic
from Panorama-Sampler"**. Both list the sessions that *triggered* a cascade in
the chosen period, **sorted by the summed waiting time of all sessions hanging on
them**. The sampler entry exists only if the recording of blocking locks is
active for the database ([Panorama Sampler](panorama-sampler.md)); it rests on lock situations the
sampler collected itself, not on ASH's blocking-session columns.

## Relationships

- A frequent, avoidable cause: [Foreign keys and locks](foreign-key-locks.md).
- Data foundation: [ASH](ash.md), alternatively [Panorama Sampler](panorama-sampler.md).
- Deliberately induced serialisation: [Cross-table uniqueness](cross-table-uniqueness.md).
- Contention on shared pool structures instead of on data:
  [Library cache contention](library-cache-contention.md).
- The retrospective evaluation resolves the hierarchy with `CONNECT BY` over ASH
  samples rounded to the same instant ([Talks on Active Session History and TEMP analysis](../sources/talks-ash-and-temp.md)).

## Open questions

- How reliable is the root detection when ASH samples capture the chain only
  patchily? The one-second sampling interval can miss short blockages →
  [ASH](ash.md).
- The post of 2020-10-06 ends with a request for feedback on whether the
  functions hold up in practice — whether any came is not known.

## Sources

- [Blog series on locks and serialisation](../sources/blog-locks.md)
- [Talks on Active Session History and TEMP analysis](../sources/talks-ash-and-temp.md)
- [Panorama's website on GitHub Pages](../sources/rammpeter-github-io.md)
