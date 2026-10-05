---
title: SQL Monitor
type: concept
status: draft
tags: [execution-plan, licensing, oracle]
created: 2026-10-01
updated: 2026-10-05
sources: [blog.md, posts/, rammpeter.github.io.md, rammpeter.github.io/]
---

# SQL Monitor

Records **individual executions** of a SQL statement in detail — not aggregates
but the concrete run.

## When recording happens

([[blog-panorama-the-tool]], 2018-03-19) One of three conditions must be met
(a fourth was added later, see below):

- execution with **parallel query**
- CPU or I/O activity for **more than 5 seconds**
- the optimizer hint **`MONITOR`** in the statement
- *(added by the usage guide, state 2026-09-02, [[rammpeter-github-io]])* an
  event set for one SQL-ID:
  `ALTER SESSION|SYSTEM SET EVENTS 'sql_monitor [sql: 5hc07qvt8v737] force=true';`
  — the guide prints `ALTER SESSION|SESSION`, read here as `SESSION|SYSTEM`

> The third condition is the interesting one: a SQL that neither runs in parallel
> nor runs long can be brought to be recorded deliberately — and without changing
> it, via a SQL patch; see [[sql-plan-management]].

## Where the reports live

| Source | Availability |
|---|---|
| `V$SQL_MONITOR` | during the execution and for a **very short** time afterwards |
| `DBA_HIST_REPORTS` / `DBA_HIST_REPORTS_DETAILS` | from 12.1, across the AWR retention period |

So from 12.1 the short-lived reports are preserved for longer — that is the
practical difference, because you rarely look in time.

Generating the HTML report:

```sql
-- from V$SQL_MONITOR
SELECT DBMS_SQLTUNE.report_sql_monitor(sql_id => :SQL_ID, Session_ID => :SID,
         Session_Serial => :SerialNo, SQL_Exec_ID => :SQL_Exec_ID,
         Inst_ID => :Instance, type => 'ACTIVE', report_level => 'ALL') FROM Dual;
-- from DBA_HIST_REPORTS
SELECT DBMS_AUTO_REPORT.REPORT_REPOSITORY_DETAIL(RID => :Report_ID, TYPE => 'ACTIVE') FROM Dual;
```

## The licence

**Tuning Pack** for the Enterprise Edition — not the Diagnostics Pack. That makes
SQL Monitor the only Panorama function with this prerequisite, and
[[panorama-sampler]] is **no** substitute here. See
[[management-pack-licensing]].

## In Panorama

A "SQL Monitor" button in three places: the SQL detail view from the current SGA,
the SQL detail view from the AWR history, and the detail view of a current
database session. A click on the report ID opens the Database Activity Report in
a new browser tab.

## Obsolete presentation

> The report is rendered in type `ACTIVE` via **Adobe Flash**. Even the 2018 post
> contains the hint to check the browser console on incomplete display, because
> Chrome in particular often rejects Oracle's Flash source URLs.
>
> Flash has been discontinued since the end of 2020. The description is therefore
> historical; how the report is presented today is not evidenced in the ingested
> sources. The post names a static HTML page as the alternative when there is no
> internet connection.

The same problem affects the **Performance Hub** from Enterprise Manager Express
(from 12.1), which Panorama embeds under "Analysis / Statistics" / "Genuine
Oracle AWR-reports" / "Performance Hub" — also Flash, and the connecting user
needs the role `EM_EXPRESS_BASIC` or `DBA`
([[blog-panorama-the-tool]], 2019-02-08).

## Presentation today

([[rammpeter-github-io]], usage guide 2.2.3, last updated 2026-09-02.) The guide
no longer mentions Flash. A click on the report ID opens the Database Activity
Report in a new browser tab; **with an internet connection it is an active page
"enriched with CSS and Javascript" loaded from `download.oracle.com`, otherwise
a static HTML page.** If the report is not shown, the advice is still to check
the browser console for active security restrictions.

> The section *Obsolete presentation* above is kept as the state of 2018/2019.
> The older claim (Flash) and the newer one (CSS and JavaScript) do not
> contradict each other; Oracle changed the technology of the active report in
> between. Not tested against a current release.

What the report offers beyond Panorama's own functions, as listed by the guide:

- the execution plan with the activity of the individual steps on a time line
- real execution counts and result counts per plan step
- real execution times and I/O operations per plan step
- the recursive SQL executed by the statement, with its share of the total time

Besides the three buttons, the menu has an entry of its own: "SGA/PGA-Details" /
"SQL-Area" / "SQL-Monitor reports", showing recorded reports from
`gv$SQL_Monitor` and `DBA_HIST_Reports` ([[sql-area]]). Two screenshots
(`sql-monitor-list.png`, `sql-monitor-report.png`) are archived, not viewed.

## Relationships

- The licence-free successor with a similar purpose is the SQL Diagnostic Report
  from 19.28 → [[optimizer-diagnostics]].
- Setting the `MONITOR` hint without changing the application:
  [[sql-plan-management]].
- Licence questions: [[management-pack-licensing]].

## Open questions

- ~~How is the Database Activity Report presented after the end of Flash?~~
  Answered 2026-10-05 for the SQL Monitor report, see *Presentation today*.
  Still open for the Performance Hub ([[genuine-oracle-reports]]).
- Which role does the SQL Monitor report need? The usage guide names
  `OEM_MONITOR` for "the SQL Monitoring plug-in"; the landing page's grant
  table does not mention SQL Monitor ([[panorama-privileges]]).
- Does the SQL Diagnostic Report ([[optimizer-diagnostics]]) practically
  supersede SQL Monitor, since it contains its data licence-free? The sources do
  not draw that connection.

## Sources

- [[blog-panorama-the-tool]]
- [[rammpeter-github-io]]
