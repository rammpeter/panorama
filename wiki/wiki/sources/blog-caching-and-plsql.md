---
title: Blog series on caching and PL/SQL
type: source
status: maintained
tags: [caching, plsql, oracle]
created: 2026-10-01
updated: 2026-10-02
sources: [blog.md, posts/]
---

# Blog series on caching and PL/SQL

Five posts from [rammpeter.blogspot.com](../usage/rammpeter-blog.md) between 2013 and 2026 about reuse: when
caching results pays off, and when it turns against you.

## The posts

| Date | Title | Focus |
|---|---|---|
| 2013-05-14 | Caching of frequently used static master data (pre 11g) | [Master data caching](../usage/master-data-caching.md) |
| 2013-05-17 | Caching of frequently used static master data (post 11g, using RESULT_CACHE) | [Master data caching](../usage/master-data-caching.md) |
| 2016-12-06 | Don't flood Oracle-DB's result cache | [Result cache](../usage/result-cache.md) |
| 2017-11-16 | How to check for appropriate sequence caching | [Sequence caching](../usage/sequence-caching.md) |
| 2026-01-14 | Check user-defined PL/SQL functions for missing DETERMINISTIC flag | [DETERMINISTIC](../usage/deterministic.md), [Declare DETERMINISTIC deliberately – but not with function based indexes](../usage/declaring-deterministic-deliberately.md) |

## Key points

**Frequent access to small tables creates hot blocks** — especially when those
tables are joined en masse by nested loops. Hash joins defuse that but require
large data transfers and possibly TEMP (2013) → [Master data caching](../usage/master-data-caching.md).

**The result cache can be flooded with a single default parameter.** A function
with `p_Date DATE DEFAULT SYSDATE` produces a new call signature **every second**
— and therefore a steady stream of new entries. The consequence is latch waits
that also hit sessions barely using the cache (2016-12-06)
→ [Result cache](../usage/result-cache.md).

**Rule of thumb for the result cache: 80 to 90 % utilisation.** Above that,
wholesale eviction and therefore latch contention threaten (2016-12-06).

**Sequences are uncached by default — `CACHE SIZE = 0`.** Every
`sequence.nextval` then triggers a **write operation** on the dictionary table
`sys.SEQ$`. With parallel use this leads to random locking scenarios in the
library cache (2017-11-16) → [Sequence caching](../usage/sequence-caching.md).

**A missing `DETERMINISTIC` can call a function a million times.** In the author's
experiment: a function with no relation to any row, 1 million table rows —
**1,000,000 calls**. With `DETERMINISTIC`: **1 call** (2026-01-14)
→ [DETERMINISTIC](../usage/deterministic.md).

## A tension between two posts

The post of 2026-01-14 explicitly recommends labelling functions as
`DETERMINISTIC` that **are not really** deterministic — such as those reading
master data — because the reuse is limited to *one* SQL execution.

The post of 2023-08-15 (in [Blog series on locks and serialisation](blog-locks.md)), by contrast, shows that precisely
this ends in `ORA-08102: index key not found`.

**Both are correct** — they are different contexts. The distinction is
consequential enough to record it explicitly:
[Declare DETERMINISTIC deliberately – but not with function based indexes](../usage/declaring-deterministic-deliberately.md).

## Notes on the evidence

**An experiment with a counter.** The proof in 2026-01-14 runs via a package
variable incremented on every function call — the number is therefore counted,
not estimated.

**An author advising against his own solution.** Both caching posts from 2013 end
with the same closing remark: *"More effective than this solution is caching
master data within application layer without access to PL/SQL."* The solution
supplied is therefore explicitly the second best.

**An imprecision conceded by the author.** The sequence query derives values per
day from the distance between creation date and current value — according to the
author *"not really exact for cycling sequences"*.

**A parser in PL/SQL.** The search for function calls in 2026-01-14 tokenises SQL
texts in PL/SQL using a list of delimiter characters and emits JSON via
`DBMS_OUTPUT` — including a deliberate catch of `ORA-06502` for matches beyond
4000 characters.

## Source files

`raw/posts/03-*`, `04-*`, `17-*`, `28-*`, `69-*`
