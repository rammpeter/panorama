---
title: Library cache contention
type: concept
status: draft
tags: [locks, shared-pool, oracle]
created: 2026-10-01
updated: 2026-10-02
sources: [blog.md, posts/]
---

# Library cache contention

Not all blocking arises on data. If an object in the library cache is touched by
very many sessions at once, the protecting structure itself becomes the
bottleneck — visible as the wait event **`library cache: mutex X`**.

## Finding the culprits

The trick from [Blog series on locks and serialisation](../sources/blog-locks.md) (2013-09-17): the `P1` column of the wait event
contains the **hash value** of the affected object. A join against
`GV$DB_OBJECT_CACHE` and `DBA_OBJECTS` turns that into the owner, type, name and
namespace of the object — that is, the object the sessions are piling up on.

The post supplies the query twice: against `GV$ACTIVE_SESSION_HISTORY` for the
current SGA and against `DBA_HIST_ACTIVE_SESS_HISTORY` for the history, each with
`HAVING COUNT(*) > 100` to filter out isolated cases. Reported are wait seconds,
average wait time and the time window of the occurrences.

> A note on the history: the join there also goes against
> `GV$DB_OBJECT_CACHE`, that is, against the **current** cache contents. Objects
> that have since been aged out of the library cache can no longer be resolved
> retrospectively.

## The remedy: MARKHOT

From Oracle 11g the problem can be reduced by **cloning** objects in the library
cache — via `DBMS_SHARED_POOL.MARKHOT`. Instead of a single entry that everyone
competes for, several then exist.

Two pitfalls the author names explicitly:

- The **exact namespace** must be given in the call.
- For a PL/SQL package, `MARKHOT` must be called **twice** — separately for
  package and body.

## Relationships

- Blocking on shared pool structures, not on data — the counterpart to
  [Blocking locks](blocking-locks.md).
- A frequent cause of pressure on the library cache is the flood of different
  SQL texts → [Bind variables and cursor sharing](bind-variables-and-cursor-sharing.md).
- The same pattern with latches on the result cache → [Result cache](result-cache.md).
- Uncached sequences produce the same kind of contention →
  [Sequence caching](sequence-caching.md).
- Data foundation: [ASH](ash.md).

## Open questions

- Which kinds of object are typically affected? The post shows the method but
  names no distribution from practice.
- What does `MARKHOT` cost — more memory in the shared pool, and how many clones
  are created?
- How do you distinguish `library cache: mutex X` from other library cache
  events? The source considers only this one.

## Sources

- [Blog series on locks and serialisation](../sources/blog-locks.md)
