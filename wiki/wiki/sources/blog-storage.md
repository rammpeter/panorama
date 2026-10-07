---
title: Blog series on storage, tablespaces and redo
type: source
status: maintained
tags: [storage, redo, oracle]
created: 2026-10-01
updated: 2026-10-04
sources: [blog.md, posts/]
---

# Blog series on storage, tablespaces and redo

Six posts from [rammpeter.blogspot.com](../usage/rammpeter-blog.md) between 2016 and 2020 on the storage side:
where there is space, where there only appears to be space, who used it up — and
why three redo log groups will freeze a database.

## The posts

| Date | Title | Focus |
|---|---|---|
| 2016-03-23 | How to identify root cause after "ORA-1652: unable to extend temp segment" | [TEMP usage](../usage/temp-usage.md) |
| 2017-02-25 | Common Oracle DB pitfall: too few redo log groups | [Redo logs](../usage/redo-logs.md) |
| 2017-06-14 | Explore free space fragmentation of tablespaces | [Tablespace fragmentation](../usage/tablespace-fragmentation.md) |
| 2018-09-19 | OLTP-Compression – what's true and what's wrong | [OLTP compression](../usage/oltp-compression.md), [OLTP compression only for tables without meaningful updates](../usage/oltp-compression-only-without-updates.md) |
| 2019-08-08 | Determining candidates for storage reorganization in Oracle-DB | [Storage reorganisation](../usage/storage-reorganisation.md) |
| 2020-03-18 | Taking fragmentation into account when calculating the free tablespace | [Tablespace fragmentation](../usage/tablespace-fragmentation.md) |

## Key points

**Free space is not the same as usable space.** For a new extent the database
needs a **contiguous** free chunk the size of the next extent. The total of free
space says nothing about that — hence `ORA-01653` despite apparently plenty of
space (2017-06-14, 2020-03-18) → [Tablespace fragmentation](../usage/tablespace-fragmentation.md).

**The better metric:** do not check the total free space, but **how many times
the largest extent in use still fits into it** (2020-03-18).

**Three redo log groups are the DBCA default and a production risk.** If the next
group cannot be used, *all* commits wait — the database freezes for seconds or
minutes (2017-02-25) → [Redo logs](../usage/redo-logs.md).

**Oracle does not return space below the high water mark by itself.** Whoever
wants it back has to reorganise — and `DBMS_SPACE.SPACE_USAGE` is too expensive
for a system-wide scan. Hence first an estimate based on row length, `PCT_FREE`
and `INI_TRANS`, then the precise check per object (2019-08-08)
→ [Storage reorganisation](../usage/storage-reorganisation.md).

**With `ORA-1652` the culprit is usually not the one reported.** The session that
receives the error may be one that only wanted a little TEMP — while others
occupied the space (2016-03-23) → [TEMP usage](../usage/temp-usage.md).

**OLTP compression behaved for years differently than documented.** Updates on
compressed columns led to uncompressed block contents and therefore to migrated
rows — in one test for **95.7 %** of all rows, with the block count rising
eighteenfold (2018-09-19)
→ [OLTP compression](../usage/oltp-compression.md), [OLTP compression only for tables without meaningful updates](../usage/oltp-compression-only-without-updates.md).

## Notes on the evidence

**A contradiction to his own statement, added later.** The post of 2018-09-19
carries an "Update 2023-05" in which the author repeats the check against release
19.18 and finds that it works *"much better now than before in Rel. 12.x"* — but
*"not completely without the risk of getting migrated rows and not deterministic
at all"*. Both states are recorded in [OLTP compression](../usage/oltp-compression.md); the decision page
[OLTP compression only for tables without meaningful updates](../usage/oltp-compression-only-without-updates.md) records that its rationale therefore
only partly holds. That decision has since been **superseded** (2026-10-04) by
[Use advanced compression with updates, and monitor migrated rows](../usage/monitor-migrated-rows-under-advanced-compression.md).

**A contradiction to the documentation, openly named.** The same post quotes
Oracle's own statement that blocks would be recompressed even after updates on
compressed columns, and counters: *"I've never seen this really working starting
from 11.2 up to 18.0."* Backed by four reproducible tests.

**A measurement tool of his own.** To measure migrated rows the author uses a
function counting `consistent gets` on access by ROWID — exactly one for a row
that has not migrated. An elegant solution to a problem `ANALYZE` does not answer
reliably.

**An explicitly fuzzy estimate.** For reorganisation the author himself calls the
columns "% unused" and "MBytes unused" a *"fuzzy view"* of the potential. The
precise statement only comes from `DBMS_SPACE`.

## Source files

`raw/posts/11-*`, `20-*`, `24-*`, `34-*`, `38-*`, `43-*`
