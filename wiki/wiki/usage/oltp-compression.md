---
title: OLTP compression
type: concept
status: draft
tags: [storage, compression, oracle]
created: 2026-10-01
updated: 2026-10-04
sources: [blog.md, posts/, speakerdeck.md, speakerdeck/]
---

# OLTP compression

`COMPRESS FOR OLTP` is described by Oracle as a transparent way to use compressed
tables in an OLTP environment. The post [[blog-storage]] (2018-09-19) checks that
— and finds a difference between documentation and behaviour.

## What Oracle says

Quoted from Oracle's "Master Note for OLTP Compression": updates behave like
inserts; columns not updated retain their compression, updated ones are initially
stored uncompressed, and when the block approaches full, compression is attempted
again.

## What the author observed

> "I've never seen this really working starting from 11.2 up to 18.0."

- **Insert and delete** work well: blocks stay compressed, no migrated rows
  arise.
- **Updates on compressed columns** lead to uncompressed block contents and
  therefore to chained or **migrated rows** — regardless of whether the new value
  is already present in the block's symbol table.

## The measurement

For measuring, a function of his own serves, `Chained_Row_Test`: it counts the
`consistent gets` on access by ROWID. For a row that has not migrated this must
be **exactly one**; any excess indicates a migration.

Four tests, 100,000 rows each, `PCTFREE 10`, `COMPRESS FOR OLTP`:

| Test | Operation | Blocks afterwards | Migrated rows |
|---|---|---|---|
| 1 | update of a **non**-compressed column (unique values) | 244 (unchanged) | 0 % |
| 2 | update of a **compressed** column, new value | 4,654 | **79.5 %** |
| 3 | update of a compressed column with a value **already in the symbol table** | 4,654 | **95.7 %** |
| 4 | delete of 10 % of the rows | 244 (unchanged) | 0 % |

> Test 3 is the decisive one: even when the new value is already in the block's
> symbol table — so the compression knows it — almost all rows migrate. The block
> count rises by a **factor of 19** in tests 2 and 3.

**The author's conclusion (as of 2018):** OLTP compression is not suitable for
tables with a substantial share of updates, because migrated rows arise on a
large scale. → [[oltp-compression-only-without-updates]] (superseded; the
current position is [[monitor-migrated-rows-under-advanced-compression]])

## Addendum 2023: partly revised

The post carries its own "Update 2023-05", in which the same test was repeated
against **release 19.18**:

> "It works much better now than before in Rel. 12.x. Not completely without the
> risk of getting migrated rows and **not deterministic at all**. But with much
> smaller amount of situations resulting in increasing storage footprint and
> migrated rows."

**Both states hold:** the measurements of 2018 relate to 11.2 up to 18.0 and are
not refuted for those releases. For 19.18 the behaviour is considerably better,
but neither risk-free nor predictable. No measurements exist for 19.18 — only the
qualitative assessment.

## Finding candidates

Tables with few or no updates remain the safest candidates — under the current
position no longer the only ones. For finding them,
`DBA_TAB_MODIFICATIONS` helps. The query from the source lists tables that

- are larger than 100 MB,
- whose updates make up less than 5 % of inserts plus deletes (or that have had
  no DML since the last analysis),
- in descending order of size,
- and that are not already compressed.

The compression state is consolidated across table, partitions and subpartitions
— where values differ, their count is reported instead of a misleading single
value.

## The talk of 2024: a third statement

([[talks-advanced-compression]], slide 17.) Six years after the post, the author
summarises the matter for an audience:

- With releases 12.x and 18.x there were problems combining `COMPRESS FOR OLTP`
  with intensive updates. Rows that no longer fitted into their block after
  decompression were moved to newly allocated overflow blocks and **stayed
  migrated** even when space in the original block became free again. In the
  extreme, the compressed table grew well beyond its uncompressed size.
- With release 19 (tested with 19.18) the behaviour "still occurs sporadically,
  but with drastically lower risk than in rel. 12.x".
- **Conclusion of the talk:** with `COMPRESS ADVANCED` on tables with a
  significant amount of update DML, "the size and relevance of migrated rows
  should be kept in view".

**Three states now stand side by side:** unsuitable (post, 2018) — much better
but not deterministic (addendum, 2023-05) — usable, with monitoring (talk,
2024-02). They are a sequence, not a contradiction: the releases differ. The
newest statement is the most authoritative for 19c and later, and since
2026-10-04 it is the wiki's position: [[monitor-migrated-rows-under-advanced-compression]].

The same talk compares all table compression methods with measurements →
[[advanced-compression]].

## Relationships

- The current position: [[monitor-migrated-rows-under-advanced-compression]]. The earlier one,
  superseded: [[oltp-compression-only-without-updates]].
- Not to be confused with [[index-compression]] — a different mechanism, a
  different assessment.
- Migrated rows are also a reorganisation topic →
  [[storage-reorganisation]].
- `DBA_TAB_MODIFICATIONS` as a measure of DML load: also in
  [[index-usage-monitoring]].

## Open questions

- How does it behave from 19.19, in 21c and 23ai? Addendum and talk both reach
  19.18.
- The post names the affected releases as "11.2 up to 18.0", the talk as "12.x
  and 18.x". Was 11.2 affected?
- What does "not deterministic at all" mean concretely — on what factors does it
  depend whether an update migrates?
- The post ends with a request for experience reports: *"Do you agree with the
  above conclusions?"* Whether there were answers is not known.

## Sources

- [[blog-storage]]
- [[talks-advanced-compression]]
