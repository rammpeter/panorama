---
title: Sequence caching
type: concept
status: draft
tags: [caching, oracle]
created: 2026-10-01
updated: 2026-10-02
sources: [blog.md, posts/]
---

# Sequence caching

The default for a sequence is `CACHE SIZE = 0`. That means: **every**
`sequence.nextval` triggers a **write operation** on the dictionary table
`sys.SEQ$`.

## What it costs

([[blog-caching-and-plsql]], 2017-11-16)

- With frequent `nextval` calls, uncached sequences cause significant performance
  degradation.
- With **parallel** sessions, frequent calls lead to random locking scenarios in
  the library cache.

> The mechanism makes the scale clear: an uncached sequence turns an apparently
> trivial operation into dictionary DML — that is, into write load on a central
> structure used by everyone.

## What caching costs and yields

The overhead is minimal: a counter and an upper bound sit in SGA memory. When the
counter reaches the bound, it is raised by the cache size and the new value is
written to `SEQ$` **once**.

The drawback: on restarting the instance, all values between the current and the
highest cached value are **lost**.

**The sizing rule** that follows:

- The interval between two cache reloads should be in the order of **hours**, not
  milliseconds.
- An instance restart must not cause a meaningful loss in the value range.

## Finding missing caches

**1. Via `DBA_SEQUENCES`** — sequences sorted by `SEQ$` updates per day. The
number of values per day is derived from
`(Last_Number - Min_Value) / (SYSDATE - Created)`; divided by the cache size that
gives the number of reloads per day. Additionally reported: what percentage of
the maximum value has already been reached — a risk in its own right.

> The author's qualification: *"not really exact for cycling sequences"* — for
> cycling sequences `Last_Number` is not a measure of the total number of calls.

**2. Via the execution count of the SQL** — `GV$SQL_PLAN` with
`Operation = 'SEQUENCE'`, joined with `GV$SQL` and `DBA_SEQUENCES`. From that,
executions and rows processed per day, again divided by the cache size.

> The second route is the more accurate one: it measures the actual usage in the
> SGA instead of inferring it from the sequence counter — and is therefore usable
> for cycling sequences too.

In [[dragnet]] under points 3.8 and 3.9.

## Relationships

- Locking in the library cache as a consequence:
  [[library-cache-contention]].
- The same basic pattern as [[result-cache]] and [[master-data-caching]]:
  weighing saved reuse against currency of data.

## Open questions

- What cache size is appropriate? The source names a criterion (hours between
  reloads), not a number.
- How does sequence caching behave with RAC — does it additionally need
  `NOORDER` or larger caches per instance? Not covered in the post.

## Sources

- [[blog-caching-and-plsql]]
