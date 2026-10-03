---
title: Index compression
type: concept
status: draft
tags: [index, oracle, storage]
created: 2026-10-01
updated: 2026-10-02
sources: [blog.md, posts/]
---

# Index compression

Key compression has existed since Oracle 9i and in favourable cases halves the
space requirement of an index — according to [[blog-indexing]] (2016-08-17) an
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

## Relationships

- Concerns indexes that are **kept** according to [[indexing]] — compressing is
  the second best solution when dropping is out of the question.
- The queries are part of [[dragnet]] in [[panorama]].
- Not to be confused with table compression → [[oltp-compression]], which is
  assessed quite differently.

## Open questions

- The post names "up to half" as the saving but gives no measurements from a real
  system. How large is the saving typically?
- What costs does the rebuild itself incur (runtime, locks, redo) and from what
  index size do they matter?
- How does compression affect the DML load? The source only considers the space
  requirement.

## Sources

- [[blog-indexing]]
