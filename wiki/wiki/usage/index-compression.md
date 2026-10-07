---
title: Index compression
type: concept
status: draft
tags: [index, oracle, storage]
created: 2026-10-01
updated: 2026-10-04
sources: [blog.md, posts/, speakerdeck.md, speakerdeck/]
---

# Index compression

Key compression has existed since Oracle 9i and in favourable cases halves the
space requirement of an index — according to [Blog series on indexing](../sources/blog-indexing.md) (2016-08-17) an
"often underrated" feature.

## Summary

The technique stores recurring leading key values only once per block. The saving
therefore depends on the key size and on the **number of rows per key value**:
the less selective the leading columns, the more can be saved.

It is applied via a rebuild:

```sql
ALTER INDEX MyIndex REBUILD COMPRESS;     -- all key columns
ALTER INDEX MyIndex REBUILD COMPRESS 2;   -- only the first two columns
```

## Which indexes are worth it?

The real question is not *how* but *which*. The post gives three SQL statements
that produce weighted recommendation lists (to be run with the privilege
`SELECT ANY DICTIONARY`):

1. **By selectivity.** Rated via `DBA_INDEXES.NUM_ROWS / DISTINCT_KEYS`,
   weighted by the average column length and the row count. Finds large indexes
   with many rows per key.
2. **By leaf block count.** Rated via `AVG_LEAF_BLOCKS_PER_KEY` — a more direct
   measure of how many blocks a key value spreads across.
3. **By the selectivity of individual columns in multi-column indexes.** Looks at
   `NUM_DISTINCT` per column position and thereby answers the follow-up question
   of *how many* leading columns should be compressed — that is, the argument of
   `COMPRESS n`.

Each of them excludes bitmap indexes and already compressed indexes
(`Compression = 'DISABLED'`).

## Three methods

([Talk on Oracle Advanced Compression in practice](../sources/talks-advanced-compression.md), 2024; [Talks on indexes](../sources/talks-indexes.md), 2020.)

| Method | Advanced Compression Option | Syntax | How |
|---|---|---|---|
| Prefix key compression | no — in all editions since 9i | `COMPRESS <n>` | deduplicates identical leading column values within a block; `n` = number of leading columns |
| Advanced low | yes (from 12.1) | `COMPRESS ADVANCED LOW` | the same, with the optimal prefix length calculated per block |
| Advanced high | yes (from 12.2) | `COMPRESS ADVANCED HIGH` | a combination of methods, far stronger; not for bitmap indexes, IOTs or function-based indexes |

Without the option you have to specify the prefix length yourself — which is
what the third recommendation list above is for.

## Measured: column order decides

A unique index over three columns on a table of 14 billion rows, interval-
partitioned by date: `DATUM` (3,049 distinct values, the partition key),
`WARENGRUPPE_ID` (7 million), `LGR_BEREICH_ID` (30). Built in both column
orders. Values read off charts, approximate.

| Size in GB | Uncompressed | `COMPRESS 1` | Advanced low | Advanced high |
|---|---|---|---|---|
| Date first | ≈ 575 | ≈ 410 | ≈ 410 | ≈ 165 |
| Date last | ≈ 575 | **≈ 650** | ≈ 570 | ≈ 175 |

| Range / skip scan per partition, ms | Uncompressed | `COMPRESS 1` | Advanced low | Advanced high |
|---|---|---|---|---|
| Date first (skip scan needed) | ≈ 121 | ≈ 122 | ≈ 111 | ≈ 67 |
| Date last (range scan) | ≈ 16 | ≈ 61 | ≈ 19 | ≈ 32 |

Unique scans took about 0.027 ms in all variants, rising to 0.033–0.039 ms with
advanced high.

What follows:

- **Prefix compression on the wrong column makes the index bigger.** With the
  7-million-value column in front, `COMPRESS 1` adds overhead and saves nothing:
  650 GB instead of 575.
- **The partition key as leading column compresses very well** — within one
  partition its values are nearly identical.
- **Advanced low protects against the mistake**: it picks the prefix per block
  and ends no larger than uncompressed.
- **Advanced high does not care about column order** and reaches under a third
  of the size either way.
- **Compression can cost on range scans**: 16 ms became 61 ms with `COMPRESS 1`
  in the order where compression did not help.

## Two problems with advanced high

- `ALTER INDEX … MODIFY PARTITION … SHRINK SPACE COMPACT` on a local partitioned
  primary key index repeatedly ended in `ORA-00600 [6302]`, not
  deterministically; unresolved with Oracle support at the time of the talk.
- The optimizer assigns such **exorbitantly low costs** to an advanced-high
  index that better-suited multi-column indexes with the same leading columns
  are not used. Workaround: choose the column order of the compressed index so
  that its leading columns occur, without redundancy, only in this index.

## Relationships

- Concerns indexes that are **kept** according to [Indexing](indexing.md) — compressing is
  the second best solution when dropping is out of the question.
- The queries are part of [Dragnet Investigation](dragnet.md) in [Panorama](panorama.md).
- Not to be confused with table compression → [OLTP compression](oltp-compression.md), which is
  assessed quite differently.
- All compression methods compared: [Table, index and LOB compression compared](advanced-compression.md). The other way to
  shrink an index: [Function-based indexes](function-based-indexes.md).

## Open questions

- ~~The post names "up to half" as the saving but gives no measurements from a
  real system.~~ Measurements now exist (see *Measured*), for one index.
- **The sources do not agree on the typical saving**, and none is wrong for its
  case: "up to half" (blog, 2016); "by 1/4 to 1/3" (talk, 2018); "at 1/3 to 1/2
  of the original size" (talk, 2020 — read literally a remaining size, possibly
  loosely worded); "up to 30 % or more" (talk, 2026); and measured here, 29 %
  saved or 13 % *added* depending on column order. The older statements are kept;
  the measurement shows why a single figure cannot exist.
- What costs does the rebuild itself incur (runtime, locks, redo) and from what
  index size do they matter?
- How does compression affect the DML load? The sources consider space and, since
  2024, read access — not DML.

## Sources

- [Blog series on indexing](../sources/blog-indexing.md)
- [Talk on Oracle Advanced Compression in practice](../sources/talks-advanced-compression.md)
- [Talks on indexes](../sources/talks-indexes.md)
- [Talks on dragnet investigation and proactive tuning](../sources/talks-dragnet-and-proactive-tuning.md)
