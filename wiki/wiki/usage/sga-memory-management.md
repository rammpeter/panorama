---
title: SGA memory management
type: concept
status: draft
tags: [shared-pool, storage, oracle]
created: 2026-10-01
updated: 2026-10-02
sources: [blog.md, posts/]
---

# SGA memory management

Since release 10.1 Oracle distributes the SGA memory automatically between the
components — buffer cache, shared pool, large pool, java pool — when only
`SGA_TARGET` is set. That often works, but not always.

## The typical skew

([[blog-panorama-the-tool]], 2018-09-05) The most frequent trigger is missing
bind variables:

```sql
-- instead of
SELECT a, b FROM Item WHERE ItemNo = :ItemNo;
-- there is
SELECT a, b FROM Item WHERE ItemNo = 453612;
SELECT a, b FROM Item WHERE ItemNo = 876886;
```

The consequence: the shared pool grows, and the automatic management shrinks the
buffer cache in exchange.

> In the worst case the SQL area in the shared pool is **considerably larger than
> the remaining buffer cache**. The result is poor SQL performance through a poor
> cache hit rate — and that for the whole database, not just for the SQL that
> caused it.

The same metric serves as a diagnosis in
[[bind-variables-and-cursor-sharing]]: if the SQL area is much larger than the
buffer cache, that is a signal of a massive bind variable problem.

## The second risk: ORA-04031

With **alternating** load patterns — sometimes DB-cache-heavy, sometimes
SQL-area-heavy — a further risk arises:
`ORA-04031: unable to allocate x bytes of shared memory`, if the resize
operations do not take effect fast enough.

## The remedy

**Define minimum values per component** — `DB_CACHE_SIZE` and
`SHARED_POOL_SIZE`, for instance. That stops the components from falling below
them, and the number of resize operations drops.

> The subtle point from the source: the sum of the minimum values may be
> **smaller** than `SGA_TARGET`. That leaves a remainder Oracle continues to
> decide about itself — you constrain the automation instead of switching it off.

## Where to look

In [[panorama]]:

- **"SGA/PGA details" / "SGA memory" / "SGA components"** — current sizes; from
  there via "Resize ops." to the most recent resize operations, and via the name
  "SQLA" into the contents of the SQL area.
- Historical resize operations are analysable as well.
- **"SGA/PGA details" / "DB-cache" / "DB-cache usage current"** — which objects
  occupy the buffer cache.

**Retrospectively for the DB cache too:** the occupancy of the DB cache by
objects is **not** part of the AWR recordings. [[panorama-sampler]] captures it
additionally — which makes a historical view possible as well.

## Relationships

- The main cause: [[bind-variables-and-cursor-sharing]], together with the
  rejected shortcut [[cursor-sharing-force-is-no-substitute]].
- Another shared pool component with an eviction problem of its own:
  [[result-cache]].
- Contention on shared pool structures:
  [[library-cache-contention]].
- Capture of historical cache occupancy: [[panorama-sampler]].

## Open questions

- How high should the minimum values be set? The source names the principle, not
  guide values.
- How does this behave with `MEMORY_TARGET` (SGA and PGA together) instead of
  `SGA_TARGET`? Not covered in the post.

## Sources

- [[blog-panorama-the-tool]]
