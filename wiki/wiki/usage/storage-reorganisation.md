---
title: Storage reorganisation
type: concept
status: draft
tags: [storage, oracle]
created: 2026-10-01
updated: 2026-10-05
sources: [blog.md, posts/, speakerdeck.md, speakerdeck/, rammpeter.github.io.md, rammpeter.github.io/]
---

# Storage reorganisation

Oracle does not return space below the high water mark automatically. Whoever
wants to make it available to other objects has to reorganise the object — and
needs to know beforehand for which object it is worth it.

## The tool and its problem

`DBMS_SPACE.SPACE_USAGE` supplies the free space in the blocks of an object and
thereby allows a prediction of the reorganisation effect.

> The problem according to [[blog-storage]] (2019-08-08): for larger objects
> `DBMS_SPACE.SPACE_USAGE` takes considerable time — scanning a whole schema or
> system with it is too expensive.

## The two-stage approach

**Stage 1 — the cheap estimate.** [[panorama]] computes from the average row
length, `PCT_FREE` and `INI_TRANS` how many blocks an object would actually need
and contrasts that with the space occupied. The result is the columns "% unused"
and "MBytes unused"; sorted descending, that yields a hit list.

The calculation takes the block layout into account in detail: block header,
transaction header (fixed plus variable per `INI_TRANS - 1`), data header, row
directory and table directory entry — and for indexes additionally the leaf
blocks and the ROWID size.

> The author himself calls these columns a "fuzzy view" of the potential. It is a
> pre-selection, not a result.

**Stage 2 — the precise check.** A click in either column leads to
`DBMS_SPACE.SPACE_USAGE` for that single object. Its four classes — 0–25, 25–50,
50–75 and 75–100 % free space per block — allow a more precise prediction. From
that Panorama computes two columns:

| Column | Meaning |
|---|---|
| "Approx. unused MBytes" | approximately unused space |
| "Freeable MBytes" | the recovery after reorganisation, **in the worst case** — that is, assuming `PCT_FREE` is already needed for row growth and has to be provided afresh after the reorganisation |

The check is also reachable directly from the detail views for tables, indexes
and LOBs.

**One exception:** for **securefile LOBs** the result of
`DBMS_SPACE.SPACE_USAGE` differs because of their special structure.

## Why save space at all, and two further places to look

([[rammpeter-github-io]], usage guide chapter 7.) The guide gives four aims of
minimising storage:

- fewer storage resources — cost, avoided hardware extensions, room for more
  applications on existing hardware
- more effective use of the DB cache — higher hit rate, less load from
  individual objects ([[db-cache-usage]])
- shorter SQL run times through less I/O and a higher cache hit rate
- protection against unplanned growth, through more free tablespace

**Recycle bin.** "Schema / Storage" / "Recycle bin" shows what dropped objects
still occupy. Selecting by size and drop time allows releasing the relevant
space "after sufficient grace period".

**Unused tables.** The guide's definition: tables with no access at all over a
longer period, *and* tables that are only written to but whose content is never
read. For indexes the counterpart is [[index-usage-monitoring]].

**A needed grant.** The exact space figures come from
`DBMS_SPACE.SPACE_USAGE`, which requires `ANALYZE ANY` or the `ANALYZE` privilege
on the object ([[panorama-privileges]]).

> The guide's sections on the storage overview, its evolution over time,
> releasing space below the high water mark, table compression, index
> compression and size tracking with the sampler are headings without text. What
> this page says about the high water mark rests on the blog and the talks.

## Relationships

- The other side of [[tablespace-fragmentation]]: there space that appears free,
  here space that appears occupied.
- Migrated rows as a reason to reorganise: [[oltp-compression]].
- For indexes, dropping is often better than reorganising → [[indexing]],
  [[index-compression]].
- Saving space by compression instead: [[advanced-compression]]. A high water
  mark that partitioning avoids: [[movex-cdc]].

## Open questions

- How accurate is the stage 1 estimate compared with `DBMS_SPACE`? The source
  calls it fuzzy without showing the deviation.
- How do you then actually reorganise — `ALTER TABLE MOVE`, online redefinition?
  The source only covers finding the candidates.
- In what way does the result differ for securefile LOBs?

## Sources

- [[blog-storage]]
- [[rammpeter-github-io]]
