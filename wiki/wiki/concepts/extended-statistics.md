---
title: Extended statistics
type: concept
status: draft
tags: [optimizer, statistics, index, oracle]
created: 2026-10-01
updated: 2026-10-02
sources: [blog.md, posts/]
---

# Extended statistics

An extended statistic (`DBA_STAT_EXTENSIONS`) describes the selectivity of an
*expression* instead of a column. Among other things it is created automatically
when a function based index is created — but it is **not populated with values**
in the process, and until that happens the optimizer ignores the index.

## The observed case

([[blog-indexing]], 2024-08-15)

A table `INVOICE` with 3.2 billion rows, plus a function based index on an
expression that mostly evaluates to `NULL`:

```sql
CREATE INDEX IX_OPENAMOUNT ON INVOICE(CASE WHEN Open_Amount > 0 THEN Customer_ID END);
```

The index contains only 4.9 million rows — under 1 % of the table — at roughly 4
rows per key. The matching query returns about 4 rows per execution. The
optimizer nevertheless chose a full table scan.

The causal chain, as the post uncovers it:

- For a function expression the optimizer estimates the cardinality by a fixed
  rule: **rows / 100**. That applies even when the expression is covered by a
  function based index.
- If you force the index with an `INDEX_RS_ASC` hint, the SQL runs fast — but the
  estimated cost of the index access (4,539,007) is twice as high as that of the
  full table scan (2,818,600). That is why the optimizer decides against it of
  its own accord.
- **The real cause:** creating the function based index also creates an extended
  statistic for the index expression. Initially it contains **no computed
  values** — visible from the fact that `DBA_TAB_COL_STATISTICS` and
  `DBA_TAB_HISTOGRAMS` stay empty for it.
- It is only populated at the next `DBMS_STATS.GATHER_TABLE_STATS`. As long as
  the values are missing, the statistic attributes known to the index do **not**
  count towards the cardinality estimate.
- `DBMS_STATS.GATHER_INDEX_STATS` alone is **not** enough — it does not create
  the values for the associated extended statistic.

## Why it is easily overlooked

The missing statistic is computed even when there is nothing else to do, because
the analysis information does not count as stale (`DBA_TAB_MODIFICATIONS`). The
`LAST_ANALYZED` date does not change in that case. So a look at
`DBA_TAB_MODIFICATIONS` gives **no** indication that a `GATHER_TABLE_STATS` would
be needed.

> Particularly critical when the automatic gathering in the daily maintenance
> window is not used — then the index stays ineffective indefinitely.

## What to do

After creating a function based index, always run
`DBMS_STATS.GATHER_TABLE_STATS`. If that is too expensive for a very large table
with thousands of partitions, the analysis can be restricted to the extended
statistic alone by naming its generated name in `Method_Opt`:

```sql
DBMS_STATS.GATHER_TABLE_STATS (TabName => 'INVOICE',
                               Estimate_Percent => 1/10000,
                               Method_Opt => 'FOR COLUMNS SYS_NC00004$ SIZE AUTO');
```

## A revised assessment

The author initially considered the behaviour a database bug ("I tended to treat
this behaviour as a bug at this time") and only found the real cause after
digging deeper. What is recorded here as fact is only the revised version; the
first assessment is **superseded** and remains only as an indication of how
easily the case is misread as an "optimizer bug".

## Relationships

- A case in which an index that exists and makes sense remains ineffective — the
  counterpart to the four roles in [[indexing]].
- Related to [[index-access-paths]]: both show that the mere existence of a
  suitable index says nothing about its effect. Both are summarised in
  [[finding-skipped-index-columns]].
- The `DETERMINISTIC` trap that also affects function based indexes:
  [[declaring-deterministic-deliberately]].
- [[panorama]] gives the column "Last analyzed" a coloured background in the
  table structure view when values for extended statistics are missing; a click
  shows the detailed statistics with the empty columns.

## Open questions

- Does the "rows / 100" rule hold unchanged across all releases? The source names
  no version.
- Does the problem also affect extended statistics created without a function
  based index (column groups via `DBMS_STATS.CREATE_EXTENDED_STATS`, say)?

## Sources

- [[blog-indexing]]
