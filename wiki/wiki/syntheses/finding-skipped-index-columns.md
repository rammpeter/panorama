---
title: Finding skipped index columns
type: synthesis
status: maintained
tags: [index, execution-plan, oracle, procedure]
created: 2026-10-01
updated: 2026-10-02
sources: [blog.md, posts/]
---

# Finding skipped index columns

**Question:** How do I find indexes where a *middle* column is not used?

Kept answer from 2026-10-01. The mechanism is in [[index-access-paths]]; this
page is the procedure.

## Short answer

Look for plan lines with `OPERATION = 'INDEX'` where **three** conditions hold at
the same time:

| # | Condition | Why |
|---|---|---|
| 1 | `ACCESS_PREDICATES` **and** `FILTER_PREDICATES` both not `NULL` | A filter being set reveals that not all access criteria were resolved via the B-tree |
| 2 | `ic.Column_Position <= p.Search_Columns` | Consider only columns within the used index prefix |
| 3 | `UPPER(p.Access_Predicates) NOT LIKE '%'\|\|ic.Column_Name\|\|'%'` | And their name does **not** appear there — that is the skipped column |

`SEARCH_COLUMNS` says how far the index is used at all. Every column within that
span that does not appear in the access criteria is iterated over during
execution — once per distinct value.

**The severity** depends solely on `DBA_TAB_COLUMNS.NUM_DISTINCT` of that column:
one distinct value costs 3–5 buffer gets, like an ordinary range scan; many
distinct values mean correspondingly many B-tree accesses — in the worst case
millions for a single, inconspicuous index access.

## The quick route

In [[panorama]] via [[dragnet]] — both queries are available there ready-made,
with direct drill-down into the SQL plan and the index structure.

## The route via SQL

Against the **current SGA** ([[blog-indexing]], 2026-06-03,
`raw/posts/71-2026-06-03-*.md`):

```sql
SELECT h.Elapsed_Secs Elapsed_Secs_In_Index_Access,
       ic.Column_Name Skipped_Ind_Column_in_Access,
       tc.Num_Distinct Num_Distinct_of_Skipped_Column,
       p.SQL_ID, p.Child_Number, p.Plan_Hash_Value, p.Options,
       p.Object_Owner Owner, p.Object_Name Index_Name, p.ID Plan_Line_ID,
       p.Search_Columns, p.Access_Predicates, p.Filter_Predicates
FROM   gv$SQL_Plan p
JOIN  (SELECT /*+ NO_MERGE */ Inst_ID, SQL_ID, SQL_Child_Number,
              SQL_Plan_Hash_Value, SQL_Plan_Line_ID, COUNT(*) Elapsed_Secs
       FROM   gv$Active_Session_History
       WHERE  SQL_Plan_Operation = 'INDEX'
       AND   (SQL_Plan_Options LIKE 'RANGE SCAN%' OR SQL_Plan_Options LIKE 'SKIP SCAN%')
       GROUP  BY Inst_ID, SQL_ID, SQL_Child_Number, SQL_Plan_Hash_Value, SQL_Plan_Line_ID
      ) h ON h.Inst_ID = p.Inst_ID AND h.SQL_ID = p.SQL_ID
         AND h.SQL_Child_Number = p.Child_Number
         AND h.SQL_Plan_Hash_Value = p.Plan_Hash_Value
         AND h.SQL_Plan_Line_ID = p.ID
JOIN   DBA_Indexes i ON i.Owner = p.Object_Owner AND i.Index_Name = p.Object_Name
JOIN   DBA_Ind_Columns ic ON ic.Index_Owner = p.Object_Owner
         AND ic.Index_Name = p.Object_Name
         AND ic.Column_Position <= p.Search_Columns  /* only columns before the last used one */
JOIN   DBA_Tab_Columns tc ON tc.Owner = i.Table_Owner
         AND tc.Table_Name = i.Table_Name AND tc.Column_Name = ic.Column_Name
WHERE  p.Access_Predicates IS NOT NULL
AND    p.Filter_predicates IS NOT NULL  /* filter set = not all criteria via B-tree */
AND    p.Operation = 'INDEX'
AND    UPPER(p.Access_Predicates) NOT LIKE '%'||ic.Column_Name||'%'
AND    h.Elapsed_Secs  > :Min_Elapsed_Time_Sec_per_Index
AND    tc.Num_Distinct > :Min_Distinct_Values_per_Skipped_Column
ORDER  BY h.Elapsed_Secs DESC;
```

Against the **AWR history** the same logic, with four differences:

- `DBA_HIST_SQL_PLAN` instead of `GV$SQL_PLAN`,
  `DBA_HIST_ACTIVE_SESS_HISTORY` instead of `GV$ACTIVE_SESSION_HISTORY`
- join via `DBID` instead of `Inst_ID`, no `Child_Number`
- additionally `AND Sample_Time > SYSDATE - :Considered_Days_Backward`
- **`COUNT(*) * 10`** instead of `COUNT(*)` — in the history only every tenth
  second is persisted

## Prerequisites

Enterprise Edition **and** the Diagnostics Pack — the source says so explicitly
(*"You'll need EE and the Diagnostics Pack to do this investigation"*). Without a
licence, [[panorama-sampler]] takes the place of [[ash]], see
[[management-pack-licensing]].

## What the source leaves open

- **The remedy.** The post describes the detection, not the fix. A different
  column order or an additional index would be the obvious candidates — but that
  is not evidenced.
- **The threshold for `NUM_DISTINCT`.** The query makes it a parameter; the
  source names no guide value.

> **Conclusion of this wiki** (not from the source): condition 3 is a **text
> search** on the column name. If one column is called `ID` and another
> `CUSTOMER_ID`, then `ID` counts as used as soon as `CUSTOMER_ID` appears in the
> predicates — the hit is lost. The error therefore goes in the direction of
> **false negative**: the result is incomplete, but not wrong. For short column
> names contained in other names, a manual counter-check is worthwhile.

## Placement

This finding belongs to a broader insight: **usage alone is no proof of quality
for an index.** The four roles in [[indexing]] answer *whether* an index is
needed; [[index-usage-monitoring]] shows *whether* it is used. This page covers
the case where it is used and still works badly. The other cases of this kind:

- [[extended-statistics]] — a suitable function based index remains ineffective
  without `GATHER_TABLE_STATS`, because the optimizer estimates the cardinality
  with a flat *rows/100*.
- [[partition-pruning]] — the same mechanism one level up: the partition key is
  in the filter but does not become an access criterion.

In all three cases the distinction between **access and filter predicate**
decides what actually happens — and in all three cases the execution plan looks
inconspicuous.

## Sources

- [[blog-indexing]] (post of 2026-06-03), `raw/posts/71-2026-06-03-*.md`
- Mechanism: [[index-access-paths]]
