---
title: Master data caching
type: concept
status: draft
tags: [caching, plsql, oracle]
created: 2026-10-01
updated: 2026-10-04
sources: [blog.md, posts/, speakerdeck.md, speakerdeck/]
---

# Master data caching

Two posts from 2013 on the same task, before and after 11g: how do you access
small, static tables frequently without creating hot blocks?

## The problem

([[blog-caching-and-plsql]], 2013-05-14)

- Frequent access to small tables carries the risk of **hot blocks** in the DB
  cache — especially when those tables are joined en masse by **nested loops**.
- Joining the master data by **hash join** instead reduces the number of block
  accesses, but requires a large data transfer for the hash operation and
  possibly access to the TEMP tablespace.

The way out: hold the master data **in the database session itself**. With session
pooling or long-lived sessions, additionally with ageing, so that the data does
not become arbitrarily stale.

## The solution before 11g

A PL/SQL package with an associative array as the cache. The essential parts:

- A `TABLE OF CacheRecordType INDEX BY BINARY_INTEGER`, indexed by the ID.
- **Ageing at no cost:** a counter variable; only every *n* accesses (1000 in the
  example) is `SYSDATE` queried at all and checked against the maximum cache age
  (0.5 days in the example). Then the cache is emptied. The frequent path
  therefore costs only an increment.
- Misses — including `NULL` as a parameter — are answered with an exception, not
  with `NULL`.
- Two functions: one for the complete record (usable only inside PL/SQL), one for
  a single field (usable in SQL).

**One explicit limitation in the original:** **no upper bound** on the cache size
is implemented — "deliberately", given the expected volumes. Users have to ensure
themselves that the caching stays within the available memory (guide value: under
10,000 records).

**A neat self-test** sits as a comment in the code: the function works correctly
if the following query returns nothing —

```sql
SELECT /*+ PARALLEL(m) */ * FROM SchemaAlias.TableAlias m
WHERE ColumnAlias != SchemaAlias.Cache_TableAlias.getColumnAliasByID(ID);
```

## The solution from 11g

([[blog-caching-and-plsql]], 2013-05-17) The same thing with `RESULT_CACHE` — the
package shrinks to a few lines, because Oracle takes over the caching:

```sql
FUNCTION getColumnAliasByID(p_ID ...) RETURN ... PARALLEL_ENABLE RESULT_CACHE;
```

The ageing becomes unnecessary, because the result cache is invalidated when the
underlying table changes — in exchange its own pitfalls apply, see
[[result-cache]].

## The author's recommendation

Both posts end with the same closing remark, which qualifies the solution
supplied:

> "More effective than this solution is caching master data within application
> layer without access to PL/SQL."

And in both cases: measure runtimes before use, to decide between caching and a
hash join.

> Both are remarkable: the author supplies a worked-out solution and says in the
> same breath that the application layer would be the better place — and that the
> decision has to be measured anyway.

## Relationships

- The 11g variant brings the problems from [[result-cache]] with it.
- Hot blocks through contention on a structure: related to
  [[library-cache-contention]].
- The related topic of "reusing function results": [[deterministic]].
- Found system-wide by the dragnet check "frequent access on small objects"
  → [[proactive-performance-tuning]].

## Open questions

- The posts are from 2013. Is the PL/SQL variant still sensible anywhere today,
  or does `RESULT_CACHE` cover all cases?
- From what access frequency and what table size is which route worthwhile? The
  source points to measurement and names no guide values.

## Sources

- [[blog-caching-and-plsql]]
