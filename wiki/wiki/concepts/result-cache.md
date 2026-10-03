---
title: Result cache
type: concept
status: draft
tags: [caching, shared-pool, oracle]
created: 2026-10-01
updated: 2026-10-02
sources: [blog.md, posts/]
---

# Result cache

Caching the results of SQL queries or PL/SQL functions — simply by adding
`RESULT_CACHE` as a hint or a flag. That very ease is the problem.

## The damage pattern

([[blog-caching-and-plsql]], 2016-12-06) Without monitoring, the ease leads to
overbooking the cache size. If the cache is excessively flooded with new entries,
significant **latch waits** arise.

> And those latch waits also hit **other, concurrent sessions** — even ones using
> only a few cache entries. The damage does not stay with the culprit.

**Rule of thumb from the source:** use only 80 to 90 % of the result cache to
avoid the risk of latch waits — wholesale eviction is to be avoided.

## The classic mistake

A PL/SQL function with a time-dependent parameter:

```sql
FUNCTION getCachedValue(p_Parameter1 IN NUMBER,
                        p_Parameter2 IN NUMBER DEFAULT NULL,
                        p_Date       IN DATE   DEFAULT SYSDATE
                       ) RETURN VARCHAR2 PARALLEL_ENABLE RESULT_CACHE;
```

It is called without the time parameter:

```sql
FOR x IN 1..10000 LOOP
  curr_val := getCachedValue(24);
END LOOP;
```

> What happens: because of `DEFAULT SYSDATE` a new call signature arises **every
> second**. The cache fills with entries that will never be hit again.
>
> The mistake sits neither in the cache nor in the loop, but in a default value
> the caller never sees.

## Monitoring

**Occupancy:** query `GV$RESULT_CACHE_OBJECTS`. In [[panorama]] under
"SGA/PGA-details" / "Result Cache" / "Current" — maximum size, percentage
utilisation and the currently stored objects in detail.

**Tracing latch waits back:** via `DBA_HIST_LATCH`, in [[panorama]] under
"Analyses / statistics" / "Latch statistics" / "Historic". The "Wait time" column
shows whether the result cache is the main reason for latch waits; from there you
can descend into individual AWR cycles and plot the course as a chart.

## Relationships

- One of the two caching variants in [[master-data-caching]] — there as the 11g
  solution.
- The same pattern as [[library-cache-contention]]: contention on a shared pool
  structure, not on data.
- Latch history comes from [[awr]].
- A further shared pool component under pressure:
  [[sga-memory-management]].

## Open questions

- How large should the result cache be sized? The source names a utilisation
  limit, not an absolute size.
- Is there a way to exclude individual functions from the result cache without
  changing their declaration?

## Sources

- [[blog-caching-and-plsql]]
