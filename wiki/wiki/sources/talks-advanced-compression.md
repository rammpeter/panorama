---
title: Talk on Oracle Advanced Compression in practice
type: source
status: maintained
tags: [storage, compression, oracle]
created: 2026-10-04
updated: 2026-10-04
sources: [speakerdeck.md, speakerdeck/2024-02-IT-Tage_Advanced-Compression.pdf]
---

# Talk on Oracle Advanced Compression in practice

One German deck from [[rammpeter-talks]], February 2024, IT-Tage: "Oracle
Advanced Compression — Erfahrungen aus dem praktischen Einsatz". 37 slides, file
`raw/speakerdeck/2024-02-IT-Tage_Advanced-Compression.pdf`.

It is the most measurement-heavy source in the wiki. Most results are bar charts;
the values below were **read off the charts** (slide images viewed separately)
and are approximate unless the slide prints the number. The test scripts are at
<https://github.com/rammpeter/oracle_benchmarks>.

## Key points

**Scope** (slide 4): table, index and LOB compression. InMemory, Data Pump and
RMAN compression are named but not covered.

**Table methods** (slide 5): basic (no DML support, no option needed), advanced /
`COMPRESS FOR OLTP` (DML, Advanced Compression Option), HCC query and archive
(no DML, option, engineered systems). Usual ratios for basic and advanced 1:2 to
1:4; with HCC 1:10 (query high, a booking history with 55 columns) and 1:64
(archive low, a stock history with 134 columns) → [[advanced-compression]].

**How to compress existing data** (slide 6): the variants of `ALTER TABLE …
MOVE`, and what each blocks → [[advanced-compression]].

**Moving one partition, measured** (slide 7): 682,000 rows, 55 columns, 10
global indexes. Compression itself takes seconds; `UPDATE INDEXES` 43 s;
`ONLINE` **3,353 s** non-parallel → [[advanced-compression]].

**The large comparison** (slides 8–16): a table of 14 billion rows, 134 columns,
over 3,000 partitions, on Exadata X6-2L Extreme Flash; one partition of 8 million
rows. Compression factor, compression time, access by ROWID, full scans from the
buffer cache and by direct path → [[advanced-compression]].

**`COMPRESS ADVANCED` and updates** (slide 17): the migrated-row problem of 12.x
and 18.x; with 19.18 "still sporadic, but with drastically lower risk".
Conclusion: for tables with a significant amount of updates, keep the size and
relevance of migrated rows in view → [[oltp-compression]],
[[monitor-migrated-rows-under-advanced-compression]].

**A pitfall with partitioned tables** (slide 18): `ALTER TABLE … COMPRESS`
changes the default for new partitions *and* the compression attribute of
existing ones — without compressing any data. Only
`MODIFY DEFAULT ATTRIBUTES` leaves existing partitions alone
→ [[advanced-compression]].

**Index methods** (slides 19–26): prefix key compression (no option), advanced
low and high (option). Sizes and access times for a 3-column unique index on the
14-billion-row table, in two column orders. Two problems with advanced high: a
non-deterministic `ORA-00600` on `SHRINK SPACE COMPACT`, and optimizer costs so
low that better-suited indexes are ignored → [[index-compression]].

**LOB compression** (slides 27–31): SecureFile `COMPRESS LOW | MEDIUM | HIGH`,
all needing the option. For JSON in CLOBs with highly redundant field names a
factor of 46:1 with `HIGH` is shown. `CREATE TABLE … AS SELECT` does not
parallelise with LOBs; create the table, then `INSERT /*+ APPEND PARALLEL */`
→ [[advanced-compression]].

**Estimating in advance** (slides 32–34):
`DBMS_COMPRESSION.Get_Compression_Ratio` — "never used successfully myself, runs
into various errors". Panorama instead offers suggestion lists, calculates the
expected size from statistics, and shows via
`DBMS_COMPRESSION.Get_Compression_Type` on a sample which rows are actually
compressed how → [[advanced-compression]].

**Conclusion of the talk** (slide 35): compression is usable in production;
depending on the profile it brings a runtime gain or loss besides the storage
saving; some of it needs testing per object, some is a "no-brainer" (advanced
index key compression could be set per tablespace); the option costs about a
quarter of the Enterprise Edition price; and a licensed option is often not used
because developers do not know what it offers.

## Impact on the wiki

- New: [[advanced-compression]].
- [[oltp-compression]] — a newer statement by the author on updates under 19c.
- New decision [[monitor-migrated-rows-under-advanced-compression]], which supersedes
  [[oltp-compression-only-without-updates]].
- [[index-compression]] — measurements, advanced index compression, two
  problems.
- [[panorama]] — the compression suggestion lists and the per-row compression
  check.

## Changes over time and disagreements

- **Updates on compressed tables.** The blog post of 2018 concluded that OLTP
  compression is unsuitable for tables with a substantial share of updates, and
  the wiki turned that into the decision
  [[oltp-compression-only-without-updates]]. This talk, six years later, no
  longer says "unsuitable" but "keep migrated rows in view". It agrees with the
  blog's own 2023 addendum and goes one step further in tone. On 2026-10-04
  the author settled it: the old decision is `superseded`, the talk's advice is
  the new one, [[monitor-migrated-rows-under-advanced-compression]].
- **Releases affected.** The blog says "11.2 up to 18.0"; the talk "12.x and
  18.x".
- **Index compression can make an index bigger.** With the wrong leading column,
  `COMPRESS 1` enlarged the index from about 575 GB to about 650 GB. Nothing in
  the blog's account of [[index-compression]] hints at that.

## Open questions

- The ROWID access time for `ARCHIVE HIGH` (24.5 ms against 0.05 ms
  uncompressed) is given without explanation of what dominates it.
- The cell smart scan with filtering on compressed data is noted as "currently
  buggy, 6 seconds" on Grid 19.19 / DB 19.18. Fixed since?
- The `ORA-00600 [6302]` was "not yet successfully clarified with Oracle
  support".

## Source files

`raw/speakerdeck.md` (pointer); PDF downloaded on 2026-10-03 into
`raw/speakerdeck/`. Chart slides were viewed as images from Speakerdeck because
no PDF renderer is installed locally.
