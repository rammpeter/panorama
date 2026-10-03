---
title: Blog series on storage, tablespaces and redo
type: source
status: maintained
tags: [storage, redo, oracle]
created: 2026-10-01
updated: 2026-10-02
sources: [blog.md, posts/]
---

# Blog series on storage, tablespaces and redo

Six posts from [[rammpeter-blog]] between 2016 and 2020 on the storage side:
where there is space, where there only appears to be space, who used it up — and
why three redo log groups will freeze a database.

## The posts

| Date | Title | Focus |
|---|---|---|
| 2016-03-23 | How to identify root cause after "ORA-1652: unable to extend temp segment" | [[temp-usage]] |
| 2017-02-25 | Common Oracle DB pitfall: too few redo log groups | [[redo-logs]] |
| 2017-06-14 | Explore free space fragmentation of tablespaces | [[tablespace-fragmentation]] |
| 2018-09-19 | OLTP-Compression – what's true and what's wrong | [[oltp-compression]], [[oltp-compression-only-without-updates]] |
| 2019-08-08 | Determining candidates for storage reorganization in Oracle-DB | [[storage-reorganisation]] |
| 2020-03-18 | Taking fragmentation into account when calculating the free tablespace | [[tablespace-fragmentation]] |

## Key points

**Free space is not the same as usable space.** For a new extent the database
needs a **contiguous** free chunk the size of the next extent. The total of free
space says nothing about that — hence `ORA-01653` despite apparently plenty of
space (2017-06-14, 2020-03-18) → [[tablespace-fragmentation]].

**The better metric:** do not check the total free space, but **how many times
the largest extent in use still fits into it** (2020-03-18).

**Three redo log groups are the DBCA default and a production risk.** If the next
group cannot be used, *all* commits wait — the database freezes for seconds or
minutes (2017-02-25) → [[redo-logs]].

**Oracle does not return space below the high water mark by itself.** Whoever
wants it back has to reorganise — and `DBMS_SPACE.SPACE_USAGE` is too expensive
for a system-wide scan. Hence first an estimate based on row length, `PCT_FREE`
and `INI_TRANS`, then the precise check per object (2019-08-08)
→ [[storage-reorganisation]].

**With `ORA-1652` the culprit is usually not the one reported.** The session that
receives the error may be one that only wanted a little TEMP — while others
occupied the space (2016-03-23) → [[temp-usage]].

**OLTP compression behaved for years differently than documented.** Updates on
compressed columns led to uncompressed block contents and therefore to migrated
rows — in one test for **95.7 %** of all rows, with the block count rising
eighteenfold (2018-09-19)
→ [[oltp-compression]], [[oltp-compression-only-without-updates]].

## Notes on the evidence

**A contradiction to his own statement, added later.** The post of 2018-09-19
carries an "Update 2023-05" in which the author repeats the check against release
19.18 and finds that it works *"much better now than before in Rel. 12.x"* — but
*"not completely without the risk of getting migrated rows and not deterministic
at all"*. Both states are recorded in [[oltp-compression]]; the decision page
[[oltp-compression-only-without-updates]] records that its rationale therefore
only partly holds.

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
