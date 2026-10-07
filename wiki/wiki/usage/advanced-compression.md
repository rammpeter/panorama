---
title: Table, index and LOB compression compared
type: concept
status: draft
tags: [storage, compression, oracle]
created: 2026-10-04
updated: 2026-10-04
sources: [speakerdeck.md, speakerdeck/2024-02-IT-Tage_Advanced-Compression.pdf]
---

# Table, index and LOB compression compared

Oracle's compression methods side by side — what each needs, what it saves and
what it costs on access — with measurements from a production-sized table.

## Summary

All of it from one talk of 2024 ([Talk on Oracle Advanced Compression in practice](../sources/talks-advanced-compression.md)). The short
version of its result: compression is usable in production; the storage saving
is reliable, the runtime effect goes both ways and depends on the access
pattern; the columnar methods save most and punish single-row access hardest.

Two neighbouring pages go deeper into one method each: [OLTP compression](oltp-compression.md)
(the update problem) and [Index compression](index-compression.md) (which indexes are worth it).

> Values marked "≈" were read off bar charts and are approximate.

## Table methods

| Method | DML supported | Advanced Compression Option | Syntax |
|---|---|---|---|
| Basic | no | no | `ROW STORE COMPRESS BASIC` |
| Advanced | yes | yes | `ROW STORE COMPRESS ADVANCED` (12.x: `COMPRESS FOR OLTP`) |
| HCC query | no | yes | `COLUMN STORE COMPRESS FOR QUERY LOW \| HIGH` |
| HCC archive | no | yes | `COLUMN STORE COMPRESS FOR ARCHIVE LOW \| HIGH` |

"DML supported" means that conventional DML keeps the data compressed. Usual
ratios for basic and advanced: 1:2 to 1:4. HCC is realistic on engineered systems
(Exadata, ODA) and the ZFS appliance.

## Compressing what already exists

| Command | Effect |
|---|---|
| `ALTER TABLE … <compress>` | only future DML is compressed |
| `ALTER TABLE … MOVE <compress>` | existing data too; **DML blocked, indexes become invalid** |
| `ALTER TABLE … MOVE PARTITION <compress> UPDATE INDEXES` | DML blocked; indexes maintained, but index partitions unusable during the move |
| `ALTER TABLE … MOVE … <compress> ONLINE` | DML possible, indexes stay usable |
| `ALTER TABLE … MODIFY DEFAULT ATTRIBUTES <compress>` | only new partitions |

Online redefinition and Automatic Data Optimization are named as further routes,
without experience of the author's own.

**What `ONLINE` costs.** One partition of 682,000 rows, 55 columns, 10 global
indexes, 115 MB:

| Action | Non-parallel | Parallel 64 | Size | Factor |
|---|---|---|---|---|
| `MOVE PARTITION … COMPRESS` | 5 s | 2 s | 36.6 MB | 3.1 |
| `… COMPRESS ADVANCED` | 5 s | 1.3 s | 36.6 MB | 3.1 |
| `… COMPRESS FOR QUERY HIGH` | 7 s | 2 s | 13.4 MB | 8.6 |
| `… FOR QUERY HIGH UPDATE INDEXES` | 43 s | 2.7 s | 13.4 MB | 8.6 |
| `… FOR QUERY HIGH ONLINE` | **3,353 s** | 340 s | 13.4 MB | 8.6 |
| `… FOR ARCHIVE LOW` | 9 s | 0.6 s | 12.8 MB | 9.0 |
| `… FOR ARCHIVE HIGH` | 12 s | 0.8 s | 11.6 MB | 9.9 |

> Conclusion: the compression is cheap, keeping ten global indexes valid is not,
> and doing it online is nearly 500 times slower than offline. The practical
> pattern the talk suggests fits that: age the data by
> [interval partitioning](interval-partitions-rolling-window.md), and compress
> partitions once they no longer receive DML.

## The large comparison

A table of 14 billion rows, 134 columns, more than 3,000 partitions, on Exadata
X6-2L Extreme Flash; one partition of about 8 million rows.

| | Uncompressed | Basic | Advanced | Query low | Query high | Archive low | Archive high |
|---|---|---|---|---|---|---|---|
| Compression factor | 1 | ≈ 17 | ≈ 17 | ≈ 25 | ≈ 49 | ≈ 57 | ≈ 57 |
| Time to compress (s, non-parallel) | — | ≈ 73 | ≈ 72 | ≈ 150 | ≈ 215 | ≈ 205 | ≈ 410 |
| **Access by ROWID, all columns (ms)** | 0.048 | 0.050 | 0.049 | 0.183 | 0.510 | 0.900 | **24.5** |
| Full scan, all 134 columns, from cache (s per 1M rows) | ≈ 17.0 | ≈ 17.7 | ≈ 18.0 | ≈ 16.2 | ≈ 16.4 | ≈ 16.7 | ≈ 18.3 |
| Full scan, **2 of 134** columns, from cache (s) | ≈ 0.76 | ≈ 1.6 | ≈ 1.6 | ≈ 0.59 | ≈ 0.57 | ≈ 0.58 | ≈ 0.62 |
| Filter on 2 columns, from cache (s) | ≈ 1.2 | ≈ 0.7 | ≈ 0.7 | ≈ 0.1 | ≈ 0.15 | ≈ 0.13 | ≈ 0.7 |
| Filter on 2 columns, direct path, no offload (s) | ≈ 0.9 | ≈ 0.4 | ≈ 0.4 | ≈ 0.11 | ≈ 0.09 | ≈ 0.08 | ≈ 0.4 |

For a full scan of all columns by direct path read with cell offload, all seven
variants ran about 15 s — no difference.

What the table says:

- **Row-store compression costs nothing on single-row access** and almost
  nothing on a scan of all columns.
- **Columnar compression makes single-row access 4 to 500 times slower.** With
  archive high, one row by ROWID takes 24.5 ms instead of 0.05 ms.
- **Reading few columns** is where the methods separate: columnar is somewhat
  faster than uncompressed, row-store compression about **twice as slow**.
- **Filtering** is faster with every method except archive high, and up to ten
  times faster with HCC query.
- Archive high buys no better factor than archive low here, at twice the
  compression time and far worse access.

> Conclusion: the choice follows the access path, not the saving. Data still
> read row by row belongs in row-store compression; data only scanned and
> filtered, in HCC query. Archive high is hard to justify on these numbers.

## Advanced compression and updates

Updates on `COMPRESS ADVANCED` tables produced migrated rows on a large scale in
12.x and 18.x; with 19.18 it "still occurs sporadically, but with drastically
lower risk". The talk's advice: for tables with a significant amount of update
DML, keep the size and relevance of migrated rows in view. Details and the
measurements: [OLTP compression](oltp-compression.md); the position derived from it:
[Use advanced compression with updates, and monitor migrated rows](monitor-migrated-rows-under-advanced-compression.md).

## A pitfall with partitioned tables

```sql
ALTER TABLE t COMPRESS …;                            -- (1)
ALTER TABLE t MODIFY DEFAULT ATTRIBUTES COMPRESS …;  -- (2)
```

(1) changes the default for new partitions **and** the compression status of all
existing partitions — without physically compressing anything. The dictionary
then claims compression the data does not have. (2) changes only the default for
new partitions. Where to look: `user_tables.COMPRESSION` / `COMPRESS_FOR`, and
for the defaults `user_part_tables.DEF_COMPRESSION` / `DEF_COMPRESS_FOR`.

## Index methods

Prefix key compression (no option), advanced low (option; chooses the prefix
length per block), advanced high (option; a combination of methods, not for
bitmap indexes, IOTs or function-based indexes). Measurements, the effect of
column order and two problems with advanced high: [Index compression](index-compression.md).

## LOB compression

SecureFile LOBs: `LOB (col) STORE AS SECUREFILE (COMPRESS LOW | MEDIUM | HIGH)`,
`MEDIUM` being the default; all levels need the option.

Example: JSON documents in a CLOB, 0.5 to 100 KB, 3.5 KB on average, with highly
redundant field names; first million rows. Table plus LOB segment shrank from
≈ 9,350 to ≈ 2,200 (low), ≈ 1,800 (medium) and ≈ 1,650 (high) — the chart gives
no unit, presumably MB. Nearly all of the LOB segment disappears; with
`ENABLE STORAGE IN ROW` the compressed documents fit into the table rows.
A second example reached **46:1** with `HIGH`.

**Parallel migration.** `CREATE TABLE … PARALLEL AS SELECT /*+ PARALLEL */` does
not parallelise with LOBs. Instead: create the empty table,
`ALTER SESSION ENABLE PARALLEL DML`, then
`INSERT /*+ APPEND PARALLEL(64) */ … SELECT /*+ PARALLEL(64) */ …`
→ [Parallel execution](parallel-execution.md).

## Estimating and checking

- `DBMS_COMPRESSION.Get_Compression_Ratio` is Oracle's estimator. The author:
  "never used successfully myself", it fails with errors in
  `SYS.PRVT_COMPRESSION`.
- [Panorama](panorama.md) offers suggestion lists for table and index compression
  ([Dragnet Investigation](dragnet.md)) and calculates an expected size from `Num_Rows`, `Avg_Row_Len`,
  `Pct_Free` and `Ini_Trans`.
- `DBMS_COMPRESSION.Get_Compression_Type` returns the compression type **per
  ROWID**. Panorama uses it on a sample of selectable size (click on
  "Compression ratio") to show how the rows of a table are really compressed —
  the check for the pitfall above.

## The licence side

The Advanced Compression Option costs about a quarter of the Enterprise Edition
price. The talk's observation: it is often licensed and then not used where it
would pay, because developers do not know what it offers.

## Relationships

- Deeper on one method each: [OLTP compression](oltp-compression.md), [Index compression](index-compression.md).
- The position on updates: [Use advanced compression with updates, and monitor migrated rows](monitor-migrated-rows-under-advanced-compression.md)
  (supersedes [OLTP compression only for tables without meaningful updates](oltp-compression-only-without-updates.md)).
- The partitioning pattern it relies on: [Partitioning](partitioning.md),
  [Interval partitions and the rolling window](interval-partitions-rolling-window.md).
- The other way to make an index small: [Function-based indexes](function-based-indexes.md).
- Space freed by reorganisation rather than compression:
  [Storage reorganisation](storage-reorganisation.md).

## Open questions

- All access measurements come from Exadata flash storage. How do the ratios
  shift on conventional storage, where physical I/O dominates?
- The compression factor of ≈ 17 for row-store methods is far above the "usual
  1:2 to 1:4" the same talk quotes. What makes this table so compressible —
  134 columns with many repeated or empty values?
- No measurements for the DML cost of advanced compression on insert-heavy
  tables.
- Automatic Data Optimization is called "promising" but untested.

## Sources

- [Talk on Oracle Advanced Compression in practice](../sources/talks-advanced-compression.md)
