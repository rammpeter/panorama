---
title: SQL plan management
type: concept
status: draft
tags: [execution-plan, optimizer, licensing, oracle]
created: 2026-10-01
updated: 2026-10-04
sources: [blog.md, posts/, speakerdeck.md, speakerdeck/]
---

# SQL plan management

The means by which the execution plan of a SQL statement can be influenced
**without changing the SQL in the application**: SQL plan baselines, SQL profiles
and SQL patches. The decisive difference between them is the licence.

## SQL plan baseline

Pins a particular plan. The route from [[blog-execution-plans]] (2016-03-20)
retrieves a **good plan from the AWR history** for this — following an idea by
Filipe Martins and rmoff:

1. In the "Complete time line of SQL", find a period with exactly one good plan
   (the "Elapsed/Execution" column for assessment, "Plan hash value" for
   distinguishing).
2. Create a SQL tuning set and populate it via
   `DBMS_SQLTUNE.SELECT_WORKLOAD_REPOSITORY` over the snap range containing the
   desired plan.
3. Load the plan as a baseline with `DBMS_SPM.LOAD_PLANS_FROM_SQLSET`, filtered
   on the `plan_hash_value`.
4. Drop the tuning set again and remove existing cursors from the SGA via
   `DBMS_SHARED_POOL.PURGE`, so that the next run hard-parses. **With RAC this
   has to be repeated per affected instance.**

[[panorama]] generates this snippet at the press of a button; the user executes
it themselves as SYSDBA.

**The author names the limitation himself:** the solution may be only temporary —
if the SQL statement is modified, it loses its binding to the baseline.

> "So a better permanent solution would be to fix the execution plan by
> appropriate analyze-info, using optimizer hints in SQL etc."

## SQL patch

Slips an optimizer hint into a SQL without changing it. Normally part of the SQL
Repair Advisor, but it can be created by hand
([[blog-execution-plans]], 2018-01-14):

- **11.1 to 12.1:** `sys.DBMS_SQLDIAG_INTERNAL.i_create_patch`
- **from 12.2:** `sys.DBMS_SQLDIAG.CREATE_SQL_PATCH`

Both variants accept either a `sql_id` or the `sql_text`; on choosing between
them see [[create-sql-patches-by-sql-text]].

Dictionary locations: `DBA_SQL_PATCHES` lists the patches, `sys.SQLOBJ$` links
name, signature, category and plan ID, `sys.SQLOBJ$DATA` contains the hint in the
XML outline structure.

**A secondary use as a measuring instrument** ([[blog-execution-plans]],
2026-06-29): a SQL patch can also inject `GATHER_PLAN_STATISTICS` to force
extended plan statistics for exactly one SQL — see [[optimizer-diagnostics]].

## The licence question

The practically most important difference ([[blog-execution-plans]], 2018-01-14
and 2026-06-29):

| Means | Additional licence needed? |
|---|---|
| SQL plan baseline | yes |
| SQL profile | yes |
| **SQL patch** | **no** — usable with Standard Edition too |

Creating a SQL patch requires the privilege `ADMINISTER SQL MANAGEMENT OBJECT`
(or a comparable one). See also [[management-pack-licensing]].

### The four techniques side by side

The talk of 2018-04 ([[talks-sql-plan-management]]) is more precise than the
blog and adds the fourth technique:

| Technique | Effect | Licence |
|---|---|---|
| SQL plan baseline | prescribes the **plan hash value** to be used | Enterprise Edition; Tuning Pack in addition for creating it from AWR data via a SQL tuning set |
| SQL profile | injects optimizer hints | Enterprise Edition + Diagnostics and Tuning Pack |
| SQL patch | injects optimizer hints, like a profile | none, Standard Edition too |
| SQL translation | replaces the complete SQL text | Enterprise Edition → [[sql-translation-framework]] |

> The table above ("additional licence needed: yes") stays correct for the route
> Panorama generates, but is refined here: it is the *creation from AWR* that
> needs the Tuning Pack, not the baseline as such.

Further points from the talk:

- A baseline does not store a plan. It prescribes a plan hash value, and the
  optimizer must be able to produce a plan with that hash by itself.
- **Panorama does not generate SQL profiles** on purpose: a SQL patch does the
  same without the edition and pack restrictions.
- In complex statements a hint in a patch must name the query block, e.g.
  `INDEX(@SEL$1 h@SEL$1, IDX_Hugo_Neu)`.
- All four bind to SQL ID or SQL text and lose the binding when the statement
  changes. They are **quick fixes until the next rollout**, not a long-term
  solution.

## In Panorama

- Every SQL detail page has a "SQL patch" button that generates a PL/SQL
  snippet; you replace the hint and execute it as SYSDBA.
- Existing patches are shown in **every** detail view of the SQL — explicitly to
  prevent misinterpretation of the execution plan.
- Full list under "SGA/PGA-details" / "SQL plan management" / "SQL patches".
- The same menu gives an overview of **all** existing directives — profiles,
  baselines, stored outlines, translations, patches — including whether each is
  really used ([[talks-sql-plan-management]], [[talks-panorama-and-sampler]]).

## Relationships

- Addresses the problem from [[execution-plans]].
- Whether a hint had any effect at all is shown by [[optimizer-hints]].
- Before dropping an index, searching for its name in baselines and patches is
  worthwhile → [[index-usage-monitoring]].
- The more powerful but more involved counterpart:
  [[sql-translation-framework]].

## Open questions

- How does a baseline behave across a database upgrade?
- Is there a way to preserve the binding to a baseline across changes to the SQL
  text?

## Sources

- [[blog-execution-plans]]
- [[talks-sql-plan-management]]
