---
title: Function-based indexes
type: concept
status: draft
tags: [index, optimizer, oracle]
created: 2026-10-04
updated: 2026-10-05
sources: [speakerdeck.md, speakerdeck/2023-10_DOAG-Regio_FunctionBasedIndex.pdf, speakerdeck/2023-11_FunctionBasedIndexes.pdf, speakerdeck/2020-12_Sicheres_identifizieren_von_nicht_relevanten_Indizes.pdf, rammpeter.github.io.md, rammpeter.github.io/]
---

# Function-based indexes

An index on the result of an expression instead of on a column. Its most useful
application here is not the transformation but the *omission*: because `NULL`
is not stored in an index, an expression that is `NULL` for uninteresting rows
yields an index containing only the rows that matter.

## Summary

([Talks on indexes](../sources/talks-indexes.md)) A function-based index can shrink an index by several orders
of magnitude and make the typical queue query — "give me the few unprocessed
rows out of millions" — a one-block access. The price is discipline: the
function must really be deterministic, and the SQL must repeat the indexed
expression exactly.

## What can be indexed

- results of built-in or user-defined functions over columns of the table
- `CASE` expressions
- a virtual column, instead of repeating the expression
- several of these, mixed with plain columns, in one multi-column index

The functions used must be deterministic.

## Indexing only the rows that matter

**The status column** (2020 talk). A table of 300 million rows; 299,999,900 are
`'P'` (processed), at most 100 are `'N'` (new).

| | Index | Query | Index size |
|---|---|---|---|
| Plain | `ON t(Status)` | `WHERE Status = 'N'` | about 3 GB |
| Function-based | `ON t(DECODE(Status, 'N', 1))` | `WHERE DECODE(Status, 'N', 1) = 1` | 1 block = 8 KB |

A factor of 375,000.

**The queue** (2023 talks). A SQL executed 6,000 times a day at 3 seconds per
execution, returning about 5 rows from a table of 27 million: the records not
yet sent (`Sent = 'N'`), further filtered by `Event_Context` and a fixed list of
`Event_Type` values. The existing index had `Sent` as its *last* column.

| | Runtime | Buffer gets in index | Index size |
|---|---|---|---|
| Before | 3 s | — | about 3 GB |
| Alternative 1: `Sent` moved to the leading position | < 100 µs | 4 | 1.5 GB |
| Alternative 2: function-based index on the unsent rows only | < 100 µs | 1 | 64 KB (the initial extent) |

```sql
CREATE INDEX IX_Min ON Test(
  CASE WHEN Sent = 'N'
        AND Event_Type IN ('DeliveryCreated', 'DeliveryUpdated')
       THEN Event_Context END);
```

Three things to note in alternative 2:

- The fixed conditions go *into* the expression; the varying one
  (`Event_Context`) is what the expression returns and what is searched for.
- `Sent` need not be an index column at all: a non-`NULL` index value already
  implies `Sent = 'N'`.
- **The query must state the condition exactly as the index does** — the same
  `CASE` expression compared with the search value. Otherwise the optimizer
  does not recognise the index.

For a multi-column index the size reduction only happens if **all** columns are
`NULL` for the rows to be left out; an entry is stored as soon as one column has
a value.

> Conclusion: alternative 1 already brings the factor of 20,000 in runtime. What
> alternative 2 adds is the storage, the cache footprint and the maintenance:
> rows leave the index when they are processed, so the index stays tiny however
> large the table grows.

## Why the function must be deterministic

`DETERMINISTIC` is the author's assertion that equal arguments always give equal
results. **The database does not check it.** Not deterministic are, for
instance, functions whose result depends on a `SELECT` inside them, or on the
system time.

The mechanism behind the damage is index maintenance:

- `INSERT` finds the leaf block for the *current* function value and adds an
  entry.
- `DELETE` and `UPDATE` must first *find* the existing entry — by computing the
  function again and searching for that value.

If the function meanwhile returns something else:

- `INSERT` works.
- `UPDATE` and `DELETE` do not find the entry: **`ORA-08102: index key not
  found`**.
- `SELECT` returns **different results depending on the access path** — a full
  scan evaluates the function now, an index scan uses the value stored at insert
  time.

The talk's demonstration, a function `AgeSecs` returning
`(SYSDATE - creation) * 86400` and declared `DETERMINISTIC`:

```sql
CREATE INDEX Log_Age ON Log(AgeSecs(Creation));
INSERT INTO Log VALUES (SYSDATE);
DELETE FROM Log;   -- fails with ORA-08102
```

The same failure from a real project — a unique function-based index whose
function looked up a column in a related table — is the starting point of
[Cross-table uniqueness](cross-table-uniqueness.md).

> This is the other side of [Declare DETERMINISTIC deliberately – but not with function based indexes](declaring-deterministic-deliberately.md): declaring
> a function `DETERMINISTIC` although it strictly is not can be a legitimate
> optimisation for *calls*, and is a data error as soon as an *index* rests on
> it.

## Finding candidates

- Indexes whose leading column has very few distinct values, with the
  interesting value rare, are the pattern of the status example. [Dragnet Investigation](dragnet.md)
  lists indexes with only one or few key values (point 1.2.2 in 2018).
- A SQL with many executions, few rows returned and a large index is the pattern
  of the queue example.
- A function-based index needs statistics on its hidden column to be estimated
  properly → [Extended statistics](extended-statistics.md).

## The example in the usage guide

([Panorama's website on GitHub Pages](../sources/rammpeter-github-io.md), usage guide 7.5.) A second worked example of indexing
only the rows that matter, with different numbers from the talks' "3 GB to one
block":

- Table with **400 million rows**, column `Status` with `'N'` (new) and `'P'`
  (processed); about **300** rows are new at any time.
- The plain index on `Status` has a **two-digit gigabyte** size and is never
  used for `'P'` — the optimizer sees from the histogram that a full scan is
  cheaper.
- `CREATE INDEX Ix_Tab ON Tab(DECODE(Status, 'N', 'N', NULL))` shrinks it "by a
  factor of 1,000,000 to a few kilobytes", since NULLs are not stored.
- The query must use the identical expression:
  `WHERE DECODE(Status, 'N', 'N', NULL) = 'N'`.

**Extended:** because mere presence in the index now means "new", the indexed
*value* is free to carry a second criterion. Instead of a two-column index on
`(Status, ArtNr)`:
`CREATE INDEX Ix_Tab ON Tab(DECODE(Status, 'N', ArtNr, NULL))`, queried with
`WHERE DECODE(Status, 'N', ArtNr, NULL) = :artnr`.

> Both `CREATE INDEX` statements as printed on the website lack a closing
> parenthesis; they are given here corrected.

## Relationships

- One of two ways to shrink an index that must stay; the other is
  [Index compression](index-compression.md). Advanced index compression *high* is not available for
  function-based indexes ([Table, index and LOB compression compared](advanced-compression.md)).
- Belongs to role 1 of [Indexing](indexing.md) — optimising access from user SQL.
- The keyword it depends on: [DETERMINISTIC](deterministic.md); the trap:
  [Cross-table uniqueness](cross-table-uniqueness.md); the position:
  [Declare DETERMINISTIC deliberately – but not with function based indexes](declaring-deterministic-deliberately.md).
- The optimizer's side of expressions in indexes: [Extended statistics](extended-statistics.md).

## Open questions

- What does maintaining the expression index cost on DML compared with the plain
  index? The talks give only read figures.
- How robust is the requirement to repeat the expression exactly — does a
  virtual column make the SQL independent of the wording?
- The German talk fixes five event types in the expression, the English two. The
  more conditions are baked in, the less reusable the index is; where is the
  sensible limit?

## Sources

- [Talks on indexes](../sources/talks-indexes.md)
- [Panorama's website on GitHub Pages](../sources/rammpeter-github-io.md)
