---
title: Talks on indexes
type: source
status: maintained
tags: [index, oracle]
created: 2026-10-04
updated: 2026-10-04
sources: [speakerdeck.md, speakerdeck/2020-12_Sicheres_identifizieren_von_nicht_relevanten_Indizes.pdf, speakerdeck/2023-10_DOAG-Regio_FunctionBasedIndex.pdf, speakerdeck/2023-11_FunctionBasedIndexes.pdf]
---

# Talks on indexes

Three decks from [Talks and slide decks by Peter Ramm](../usage/rammpeter-talks.md): one on safely removing indexes, and a talk
on function-based indexes in a German and an English version.

## The decks

| Date | Title | Venue / language | Slides | File in `raw/speakerdeck/` |
|---|---|---|---|---|
| 2020-12 | Sicheres Identifizieren von nicht relevanten Indizes | German | 30 | `2020-12_Sicheres_identifizieren_von_nicht_relevanten_Indizes.pdf` |
| 2023-10 | Effiziente Nutzung von function-based Indexes | DOAG Regio, German | 12 | `2023-10_DOAG-Regio_FunctionBasedIndex.pdf` |
| 2023-11 | Efficient use of function-based indexes | English | 11 | `2023-11_FunctionBasedIndexes.pdf` |

The 2020 deck is the talk version of the blog post of 2019-12-27
([Blog series on indexing](blog-indexing.md)) and agrees with it throughout. The English
function-based-index deck drops the last topic of the German one.

## Key points

**Four roles, and why nobody acts on them** (2020, slides 4–6). User SQL,
uniqueness, foreign key protection, partition exchange — unchanged from the
blog. The reasons unused indexes stay: no role in the project owns the task (the
DBA lacks the business view, the developer the means of assessment), and "never
touch a running system" → [Indexing](../usage/indexing.md).

**Even proven use does not save an index** (2020, slide 26). Three cases:
partitioning already filters as well as the index; an index fast full scan could
run over another index; the columns are covered by another multi-column index.

**Two ways to make a kept index smaller** (2020, slides 28–29): index only the
relevant rows with a function-based index, and compress
→ [Function-based indexes](../usage/function-based-indexes.md), [Index compression](../usage/index-compression.md).

**The size example** (2020, slide 28). A table of 300 million rows with a status
column: 299,999,900 rows `'P'`, at most 100 rows `'N'`. An index on the column:
about 3 GB. An index on `DECODE(Status, 'N', 1)`: one block of 8 KB — smaller by
a factor of 375,000 → [Function-based indexes](../usage/function-based-indexes.md).

**What a function-based index is** (2023, slide 5). An index on function results
or `CASE` expressions over columns of the table; functions must be
deterministic; virtual columns can be indexed instead of the expression; `NULL`
values are not physically in the index — which is the lever for size
→ [Function-based indexes](../usage/function-based-indexes.md).

**Why determinism matters, mechanically** (2023, slides 6–8). Index maintenance
on `DELETE` and `UPDATE` *searches* the old entry by the old value. If the
function now returns something else, the entry is not found: `ORA-08102`. And a
`SELECT` returns different results by full scan (current function value) and by
index scan (value at insert time). The deck shows it with a function depending
on `SYSDATE` → [DETERMINISTIC](../usage/deterministic.md), [Function-based indexes](../usage/function-based-indexes.md).

**The queue example** (2023, slides 9–10). A SQL run 6,000 times a day at 3
seconds, selecting about 5 rows from 27 million, looking for not-yet-sent
records. Alternative 1, moving the `Sent` column to the front of the existing
index: under 100 µs, 4 buffer gets, index still 1.5 GB. Alternative 2, a
function-based index containing only the unsent rows: under 100 µs, **1** buffer
get, index 64 KB. The SQL must repeat the indexed expression exactly
→ [Function-based indexes](../usage/function-based-indexes.md).

**The uniqueness trap** (2023-10 only, slide 11): a unique function-based index
whose function selects from a related table worked until the related data
changed → [Cross-table uniqueness](../usage/cross-table-uniqueness.md).

## Impact on the wiki

- New: [Function-based indexes](../usage/function-based-indexes.md).
- [Indexing](../usage/indexing.md) — the organisational reasons and the three cases of dispensable
  used indexes are confirmed; link to the new page.
- [Index compression](../usage/index-compression.md) — savings figure, advanced index compression.
- [DETERMINISTIC](../usage/deterministic.md), [Cross-table uniqueness](../usage/cross-table-uniqueness.md) — the mechanism behind
  `ORA-08102`.
- [Index usage monitoring](../usage/index-usage-monitoring.md) — confirmed, no new content.

## Changes over time and disagreements

- **Index compression saving**: the 2020 deck says the achievable reduction lies
  "at 1/3 to 1/2 of the original size". Read literally that is a *resulting*
  size, i.e. a saving of one half to two thirds — more than the "up to half" of
  the blog and the "1/4 to 1/3" of the 2018 talk. Possibly loosely worded;
  recorded in [Index compression](../usage/index-compression.md).
- **Number of fixed conditions in the queue example**: the German deck lists five
  event types in the index expression and says "the 5 conditions"; the English
  deck lists two and says "the two conditions". The same example, simplified.

## Open questions

- The function-based-index decks give runtimes and buffer gets but not the DML
  cost of maintaining the expression index compared with the plain one.

## Source files

`raw/speakerdeck.md` (pointer); PDFs downloaded on 2026-10-03 into
`raw/speakerdeck/`.
