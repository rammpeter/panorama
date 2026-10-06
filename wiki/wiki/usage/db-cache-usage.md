---
title: DB cache usage
type: entity
subtype: component
status: draft
tags: [panorama, menu, sga, objects]
created: 2026-10-05
updated: 2026-10-05
sources: [rammpeter.github.io.md, rammpeter.github.io/Oracle_performance_analysis_with_Panorama.html, rammpeter.github.io/panorama_content_generated.html]
---

# DB cache usage

The submenu "SGA/PGA-Details" / "DB-Cache" of [[panorama]]: which objects occupy
the buffer cache, now and — with [[panorama-sampler]] — in the past.

## The entries

([[rammpeter-github-io]], menu overview.)

| Entry | Purpose as stated |
|---|---|
| DB-cache usage current | "Current content of DB-cache" |
| DB-cache advice | "Historic view on what-happens-if-analysis for change of cache size" |
| DB-cache usage historic | "Historic view on DB-cache usage by Panorama_Cache_Objects" |

## Current

(Usage guide 2.3.4.1.) Lists the concrete objects in the DB cache with the memory
each occupies. From an object it leads on to the **SQL statements currently in
the SGA** that touch it, and to its structure ([[describe-object]]).

The data source is the buffer header view — `v$BH` in the sampler's architecture
picture, `gv$BH` in the grant list for Autonomous Database
([[panorama-privileges]]).

## Historic — only with the sampler

(Usage guide 2.3.4.2.) **The entry exists only if the sampler's recording of DB
cache usage is active for the database.** Oracle's AWR does not record cache
occupancy by object; the sampler stores it in `Panorama_Cache_Objects`.

- If the period spans several snapshots, **weighted averages** are shown.
- Links in the columns lead to the object's structure, to the **SQL executed in
  the period with the object in its execution plan**, and to the history of the
  individual cache snapshots for the object, including a diagram.
- A click on the time of one snapshot lists **all** cache objects of that
  snapshot.

## Why look at it

The guide names the aim under storage (chapter 7): smaller objects mean "more
effective use of the DB cache (higher cache hit rate, less load from individual
objects)". And under memory configuration (4.2): the goal is usually to give as
much physical memory as possible to the DB cache and the In-Memory area and to
limit the shared pool to what is necessary → [[sga-memory-management]].

> Conclusion: the view turns "the cache is too small" into "these objects fill
> it". A large index that sits in the cache although only a sliver of it is ever
> queried is the case [[function-based-indexes]] and [[index-compression]]
> address; an object that should not be read at all is a plan problem
> ([[index-access-paths]]).

## Relationships

- Listed in [[panorama-menu-overview]]; part of the third pillar in
  [[panorama-analysis-workflows]].
- The sampler domain behind "historic": [[panorama-sampler]],
  [[panorama-sampler-internals]] (default: every 30 minutes).
- "DB-cache advice" has a sampler replacement too (`DBA_Hist_Cache_Advice`).

## Open questions

- How the weighting of the averages is done is not stated.
- "DB-cache advice" is described only by its one-line purpose.

## Sources

- [[rammpeter-github-io]]
