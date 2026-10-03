---
title: Index access paths
type: concept
status: draft
tags: [index, execution-plan, oracle]
created: 2026-10-01
updated: 2026-10-02
sources: [blog.md, posts/]
---

# Index access paths

An `INDEX RANGE SCAN` in the execution plan looks harmless. But it can contain
the same expensive iteration as an `INDEX SKIP SCAN` — just without the plan
revealing it.

## The known case: SKIP SCAN

If only trailing columns of an index are used as filter conditions and the
leading ones are missing, the optimizer may choose an `INDEX SKIP SCAN`. During
execution the database then iterates over **all distinct values of the skipped
column** and performs a B-tree access with the remaining criteria for each
([[blog-indexing]], 2026-06-03).

The efficiency therefore depends solely on the number of those distinct values:

- If the skipped column has **one** distinct value, the skip scan costs 3–5
  buffer gets, the same as an ordinary range scan.
- If it has **many**, the B-tree access is repeated that many times — thousands
  or millions of buffer gets for a single index access.

## The inconspicuous case: RANGE SCAN with a gap

The same happens on an access reported as an `INDEX RANGE SCAN` when **middle**
columns of the index do not serve as access criteria but subsequent ones do:

1. B-tree access via the leading used columns.
2. Iteration over all values of the skipped column.
3. Per iteration a further B-tree access with the next used index column.

Runtime and buffer gets can rise dramatically as a result, even though the
operation looks innocuous and the number of rows returned is small.

## How to recognise it

Two indications in the plan ([[blog-indexing]], 2026-06-03):

- **Both predicate columns are populated.** `ACCESS_PREDICATES` *and*
  `FILTER_PREDICATES` are not `NULL`. The comment in the original gives the
  reason: "Filter is set if not all access criteria are scanned by B-tree access"
  — a filter being set reveals that not all access criteria were resolved via the
  B-tree.
- **An index column within the used prefix is missing from the access
  criteria.** That is the actual criterion, and it consists of two parts:

  | Condition | Meaning |
  |---|---|
  | `ic.Column_Position <= p.Search_Columns` | consider only columns *before* the last used column |
  | `UPPER(p.Access_Predicates) NOT LIKE '%'\|\|ic.Column_Name\|\|'%'` | and whose name does **not** appear there |

  `SEARCH_COLUMNS` therefore says how far the index is used at all; every column
  within that span that does not appear in the access criteria is a skipped
  middle column.

Two thresholds keep the result usable: the time spent in the index access
(`:Min_Elapsed_Time_Sec_per_Index`) and — decisive for the severity —
`DBA_TAB_COLUMNS.NUM_DISTINCT` of the skipped column
(`:Min_Distinct_Values_per_Skipped_Column`).

The post supplies two SQL statements that search for the pattern system-wide —
against the current SGA (`GV$SQL_PLAN` + `GV$ACTIVE_SESSION_HISTORY`) and against
the AWR history (`DBA_HIST_SQL_PLAN` + `DBA_HIST_ACTIVE_SESS_HISTORY`), each
sorted by the time spent in the index access. The ASH side filters on
`SQL_PLAN_OPERATION = 'INDEX'` and
`SQL_PLAN_OPTIONS LIKE 'RANGE SCAN%' OR LIKE 'SKIP SCAN%'` — both variants are
searched for together.

> On the weighting: the SGA variant counts ASH samples directly (`COUNT(*)`), the
> AWR variant multiplies by 10, because only every tenth second is persisted
> there.

**Prerequisite:** Enterprise Edition and the Diagnostics Pack — the source points
this out explicitly. See [[management-pack-licensing]].

## Relationships

- **The procedure including the ready-made query:**
  [[finding-skipped-index-columns]].
- Shows that an index "used" according to [[indexing]] can still work badly —
  usage alone is no proof of quality.
- Relies on [[ash]] to weight the time consumed per plan line.
- The queries are part of [[dragnet]] in [[panorama]].

## Open questions

- What is the remedy? The source describes the detection, not the fix. A
  different column order or an additional index would be the obvious candidates —
  but that is not evidenced.
- From what number of distinct values of the skipped column does it become
  practically relevant? The query makes it a parameter; the source names no
  guide value.
- The `NOT LIKE` on the column name is a text search. If one column contains
  another's name as a substring (such as `ID` in `CUSTOMER_ID`), it can wrongly
  count as used — the hit would then be lost. The source does not address this.

## Sources

- [[blog-indexing]]
