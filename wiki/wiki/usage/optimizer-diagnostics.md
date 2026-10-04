---
title: Optimizer diagnostics
type: concept
status: draft
tags: [optimizer, execution-plan, oracle]
created: 2026-10-01
updated: 2026-10-02
sources: [blog.md, posts/]
---

# Optimizer diagnostics

Three tools for digging deeper when the execution plan alone does not answer the
question: the optimizer trace, the extended plan statistics and the SQL
Diagnostic Report. What all three have in common is that they work **without
access to the database server's file system** and **without changing the
application**.

## Optimizer trace (event 10053)

Shows how the optimizer arrived at its decision. Three routes
([[blog-execution-plans]], 2026-03-31):

```sql
ALTER SESSION SET EVENTS '10053 TRACE NAME CONTEXT FOREVER, LEVEL 1';
ALTER SESSION SET EVENTS 'TRACE[rdbms.SQL_Optimizer.*][sql:6jksrnjx4zvuk]';
EXEC DBMS_SQLDIAG.DUMP_TRACE(p_sql_id, p_child_number, p_component, p_file_id);
```

The third is the most practical: `DBMS_SQLDIAG.DUMP_TRACE` takes a SQL that
already has a valid plan in the SGA and parses it again. With
`p_component => 'Compiler'` that happens even when only a soft parse would
actually be needed.

You do not have to look for the generated file on the server: via the
`p_file_id` you assign yourself you find it in `GV$DIAG_TRACE_FILE_CONTENTS` and
read the contents via SQL.

> Note from the source: when reading, do **not** order by `Line_Number` — the
> original order within a line number should be preserved.

In [[panorama]]: the entry "Create optimizer parsing trace" in the hamburger
menu of the SQL detail view.

## Extended plan statistics

Per plan line — each as a total and as the most recently captured value
([[blog-execution-plans]], 2026-06-29):

- the number of starts of this plan line
- the number of rows returned
- the number of buffers read (consistent / current)
- the number of disk reads and writes
- the elapsed time

Three ways to switch them on — `STATISTICS_LEVEL=ALL` globally, the same via
`ALTER SESSION`, or the hint `/*+ GATHER_PLAN_STATISTICS */` in the SQL. The hint
would be the most targeted, but it requires a change to the application source
code and therefore a redeployment.

**The way out:** inject the hint via a SQL patch, measure, drop the patch again.

```sql
-- create
DECLARE patch_name VARCHAR2(32767);
BEGIN
  patch_name := sys.DBMS_SQLDiag.create_SQL_patch(
    sql_id    => '2rf0uw3hgtwc1',
    hint_text => 'GATHER_PLAN_STATISTICS',
    name      => 'GATHER_PLAN_STATISTICS for 2rf0uw3hgtwc1');
END;
/
-- remove again after the analysis
EXEC DBMS_SQLDiag.Drop_SQL_Patch('GATHER_PLAN_STATISTICS for 2rf0uw3hgtwc1');
```

Afterwards the values are in `V$SQL_PLAN_STATISTICS`. The SQL remains unchanged
and subsequently no longer carries the overhead of the capture either.
[[panorama]] shows the values as additional columns in the plan, converted per
SQL execution and per individual start of the plan line.

## SQL Diagnostic Report

From **19.28** (a backport from 23ai) `DBMS_SQLDIAG.REPORT_SQL` delivers a
combined report on a SQL: plan information, optimizer statistics, object
information, ASH data, SQL Monitor reports and more
([[blog-execution-plans]], 2025-08-07). It returns a CLOB containing HTML.

```sql
DBMS_SQLDIAG.Report_SQL(SQL_ID => 'my SQL-ID', Level => 'ALL')
```

In [[panorama]] from 19.28 as a "Diag. report" button on the SQL detail page.

**On licensing** — the author checked instead of relying on the documentation:
according to current documentation neither Enterprise Edition nor a management
pack licence is needed, even though the report contains ASH and SQL Monitor
data. The counter-check on a fresh 23.9 database via
`DBA_FEATURE_USAGE_STATISTICS`: after the call the only additionally marked item
was "Oracle Utility Metadata API", not a licensable feature. See
[[management-pack-licensing]].

> A limitation the author names himself: the supporting MOS note
> (Doc ID 1509192.1) was last updated in 2022. The statement is evidenced, but
> not for all time.

## Relationships

- Picks up where [[execution-plans]] and [[optimizer-hints]] stop.
- The tool of choice for hint injection is the SQL patch →
  [[sql-plan-management]].
- Licence questions: [[management-pack-licensing]].
- Reading trace files via SQL is also how [[sql-trace]] output is retrieved;
  [[panorama]] lists server trace files.
- Possibly supersedes [[sql-monitor]] in practice, since its data is included
  licence-free — the sources do not draw that connection.

## Open questions

- How does one read a 10053 trace sensibly? The source shows how to obtain it,
  not how to interpret it.
- What overhead does `GATHER_PLAN_STATISTICS` cause per execution?

## Sources

- [[blog-execution-plans]]
