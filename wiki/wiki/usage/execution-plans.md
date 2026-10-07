---
title: Execution plans
type: concept
status: draft
tags: [core, execution-plan, optimizer, oracle]
created: 2026-10-01
updated: 2026-10-02
sources: [blog.md, posts/]
---

# Execution plans

The route the database chooses to answer a SQL statement. For analysis it is not
the individual plan that counts so much as its **stability**: a permanently
mediocre plan is manageable, a changing one is not.

## Changing plans

> "Changing or alternating execution plans often contains the risk of
> unpredictable runtime for SQL-statements."
> — [Blog series on execution plans and the optimizer](../sources/blog-execution-plans.md), 2016-04-27

Plans are distinguished by the **plan hash value**. Five ways to find changing
plans (ibid.):

1. **SGA, current** — the "P." column in the SQL area list counts the different
   plans per SQL; highlighted orange when there is more than one.
2. **AWR history** — the same column for the chosen period.
3. **SQL detail page** — the number of plans in the period under consideration,
   top right.
4. **"Complete time line of SQL"** — the entire AWR history of a SQL, grouped by
   time units, with the plan count per time window. The column
   "Elapsed/Execution" serves to assess plan quality.
5. **System-wide scan** — in [Dragnet Investigation](dragnet.md) under point 2.6, sorted by relevance
   (the difference between the best and the worst plan per execution).

To compare several plans, [Panorama](panorama.md) marks the differences line by line in
orange or red — which for large plans makes the difference between findable and
unfindable.

**Trail to the cause:** several plans in the SGA can stem from separate child
cursors. The button "Cursor sharing (n versions)" shows the reasons
→ [Bind variables and cursor sharing](bind-variables-and-cursor-sharing.md).

## Access and filter predicates in the AWR history

Which condition acts as an *access* criterion and which as a *filter* criterion
on which plan line is often decisive for interpretation — see
[Index access paths](index-access-paths.md), where exactly this distinction makes the problem visible.

In `V$SQL_PLAN` these columns have always been present. In `DBA_HIST_SQL_PLAN`
they were only populated **from release 19.19** (a backport from 21c) — after,
as the author notes, "decades of complaints" ([Blog series on execution plans and the optimizer](../sources/blog-execution-plans.md),
2023-12-20).

**The trap in it:** plans stored in the AWR before 19.19 have no time reference.
They therefore stay **permanently** without predicate columns as long as their
SQL keeps appearing in new AWR snapshots — independently of the AWR retention.
The upgrade alone therefore does not fix the deficiency.

The remedy from the source: delete the old plans from `sys.WRH$_SQL_PLAN` once,
so that they are stored afresh from the SGA at the next snapshot — then with
predicates. The post supplies a script for this that loops in two-second
transactions; runtime according to the author roughly 10 to 60 minutes.

> Placement: a direct intervention in a `WRH$` base table is unusual and should
> be undertaken with corresponding care. The source names no risks, but also no
> alternative supported by Oracle.

## Relationships

- Plans can be kept stable via [SQL plan management](sql-plan-management.md).
- What the database did with existing hints is told by [Optimizer hints](optimizer-hints.md).
- Digging deeper: [Optimizer diagnostics](optimizer-diagnostics.md).
- Historical plans come from [AWR](awr.md), the time weighting from [ASH](ash.md).
- The same access-versus-filter distinction one level up:
  [Partition pruning](partition-pruning.md).

## Open questions

- What risks does deleting from `sys.WRH$_SQL_PLAN` actually carry? The source
  does not assess them.
- From what number of plans per SQL is the investigation worthwhile? The source
  names no threshold.

## Sources

- [Blog series on execution plans and the optimizer](../sources/blog-execution-plans.md)
