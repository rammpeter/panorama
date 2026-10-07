---
title: Panorama's website on GitHub Pages (rammpeter.github.io)
type: source
status: draft
tags: [panorama, website, documentation]
created: 2026-10-05
updated: 2026-10-06
sources: [rammpeter.github.io.md, rammpeter.github.io/]
---

# Panorama's website on GitHub Pages (rammpeter.github.io)

The four public documentation pages of [Panorama](../usage/panorama.md): the landing page, the page
on [Panorama Sampler](../usage/panorama-sampler.md), an introductory usage guide, and a menu overview
generated from the source code.

## The source

`raw/rammpeter.github.io.md` is a pointer with four URLs. The pages were fetched
on **2026-10-05** and archived as HTML, together with the 16 images they
reference, in `raw/rammpeter.github.io/`. They are living documents.

**Two snapshots on the same day.** After the first ingest the website was
republished (HTTP `Last-Modified` 2026-10-05 13:03 UTC), and the user asked for
the ingest to be repeated. The four changed HTML pages are archived unmodified
next to the first snapshot in `raw/rammpeter.github.io/2026-10-05-1303/`; the
first snapshot was not overwritten. The 16 images and `panorama_content.html`
are byte-identical. **Unless marked otherwise, statements below hold for both
snapshots.** The differences are listed under *What changed between the
snapshots*.

| Page | Archived as | State |
|---|---|---|
| Landing page "Panorama for Oracle databases" | `panorama.html` | no date |
| "Panorama-Sampler for Oracle databases" | `panorama_sampler.html` | no date |
| "Performance analysis of Oracle-DB with Panorama: Introduction" | `Oracle_performance_analysis_with_Panorama.html` | last updated 2026-09-02 (first), 2026-10-05 13:02 UTC (second); marked "not yet completed and still under construction" |
| "Panorama: function overview by top level menu entries" | `panorama_content_generated.html` | generated from source code 2026-09-02 (first), 2026-10-05 13:02 UTC (second) |

**A wrong URL in the pointer — fixed.** Until 2026-10-05 the pointer named
`panorama-sampler.html`, which returns 404; the page lives at
`panorama_sampler.html` (underscore) and was read from there. The pointer was
corrected by the user (commit `0277846f`, 2026-10-06). `panorama_content.html`,
linked from the landing page, is only a redirect to the generated page and is
archived too.

**Third check, 2026-10-06.** The website was republished again (`Last-Modified`
2026-10-06 04:54 UTC) by its automatic generation. Compared with the second
snapshot, the landing page and the sampler page are byte-identical; the guide
and the menu overview differ **only in their timestamp lines**; the 16 images
are byte-identical. No third
snapshot was archived for that. The guide's source,
`Oracle_performance_analysis_with_Panorama.adoc` in the local checkout of the
website repository (last commit `ebfb2de`, 2026-10-05), was read alongside and
shows the same text — the open points below are in the source, not artefacts of
the generation.

**Images.** Three were viewed: `Panorama_Overview.png` (network connections),
`Panorama-Sampler.png` (the sampler's architecture, the same picture as in the
talks) and `table.png` (a grid with its context menu and chart). The other 13 —
screenshots of Panorama views — were archived but not viewed.

## Summary

The **landing page** is the operating manual in short form: what the tool offers,
which grants the login user needs, how to start it as JAR or container, every
configuration setting, the security model and a list of implementation details.
The **sampler page** does the same for the sampler: setting it up, the grants of
its user, the AWR views it replaces, its limits against AWR, a health endpoint
and a script that redirects foreign AWR scripts to sampler data. The **guide**
walks through analysis along three pillars — sessions, SQL, objects — and then
through configuration checks, application design, plan control and storage; about
a third of its sections are empty or carry a "TODO: Transfer content from german
document". The **menu overview** lists every menu entry with a one-line
description and is the only one of the four that is generated rather than
written.

## Key points

**Landing page**

- Self-description: "my swiss army knife for performance analysis and
  troubleshooting on Oracle databases"; a GUI with predefined workflows "instead
  off dealing by hand with lots of SQL scripts".
- Audience: DBAs "and also … software developers with less Oracle knowledge".
- Panorama "only reads via SELECT-SQLs"; no write access, no objects of its own,
  nothing to compile in the analysed database.
- Supported: standard hardware, RAC, Exadata, Autonomous Database in OCI; tested
  from Oracle 11.2. The dragnet scan covers "more than 100 considered aspects".
- A table of grants for the login user, with the reason for each
  → [Privileges for Panorama](../usage/panorama-privileges.md).
- Java 21 or higher; a browser with ES6 support.
- Licence: GNU General Public License v3, free of charge.
- All configuration settings, command-line options `-p`/`--port` and
  `-b`/`--bind`, container mounts → [Panorama operations](../usage/panorama-operations.md),
  [Panorama configuration](../development/panorama-configuration.md).
- A public demo installation → [Panorama operations](../usage/panorama-operations.md).
- The security model in six points → [Client state and security in Panorama](../development/panorama-client-state-and-security.md).
- Implementation details: connection pool, single-page rendering by AJAX (the
  browser's back button does not work), `Usage.log`, a pool view at
  `/usage/connection_pool`.

**Sampler page**

- Five functions: replacement for AWR and ASH, object sizes, DB cache usage by
  objects, blocking locks, long-term storage of condensed ASH.
- Enabled by starting the server with `PANORAMA_MASTER_PASSWORD`; several master
  passwords give several configuration sets, of which only the one the server
  was started with is sampled.
- Grants of the sampling user → [Privileges for Panorama](../usage/panorama-privileges.md).
- 38 replaced views, listed by name.
- Limits against AWR, for ASH and for segment statistics.
- A health endpoint for monitoring tools and a synonym script for foreign AWR
  scripts → [Panorama Sampler](../usage/panorama-sampler.md).

**Guide**

- Two ways of analysis (current state from `V$` and dictionary views;
  retrospective from recorded data) and three pillars (sessions, SQL, objects)
  → [Analysis workflows in Panorama](../usage/panorama-analysis-workflows.md).
- How the interface is driven, globally and in tables
  → [Analysis workflows in Panorama](../usage/panorama-analysis-workflows.md).
- Menu paths and behaviour for the session list, session waits, ASH, locks, SQL
  area, SQL Monitor, object description, segment statistics, DB cache, init
  parameters, SGA, redo logs, I/O, audit trail → the menu pages listed in
  [Panorama menu overview](../usage/panorama-menu-overview.md).
- Application design: only the section on `DBMS_Application_Info` is written
  ([Session context](../usage/session-context.md)); bind variables, PL/SQL in SQL (`PRAGMA UDF`, package
  constants), indexing, constraints and views are headings with TODO.
- Plan control: baselines, profiles, patches, translations
  ([SQL plan management](../usage/sql-plan-management.md)), preceded by the demand for realistic object
  statistics ([Describe object](../usage/describe-object.md)).
- Storage: four goals of saving space, recycle bin, function-based index example
  ([Function-based indexes](../usage/function-based-indexes.md)), unused tables and indexes
  ([Storage reorganisation](../usage/storage-reorganisation.md), [Index usage monitoring](../usage/index-usage-monitoring.md)).

**Menu overview**

- Seven top-level menus and 124 entries (123 in the first snapshot)
  → [Panorama menu overview](../usage/panorama-menu-overview.md).

## Contradictions and ageing

Within the source, and against the wiki. None was overwritten silently; each is
recorded on the page concerned.

1. **Idle pooled connections — resolved.** First snapshot: terminated "10
   minutes after last usage"; code ([PanoramaConnection](../development/panorama-connection.md)): after one hour.
   The user stated in the session that the code is authoritative. Second
   snapshot: "one hour after last usage". Source and code agree.
2. **`OEM_MONITOR` "as of DB Release 11.4"** (guide) against "starting with
   Oracle 11.2.0.4" (landing page). There is no release 11.4; read as a slip in
   the guide. See [Privileges for Panorama](../usage/panorama-privileges.md).
3. **Which role for what.** The guide names `OEM_MONITOR` for "AWR and ASH
   reports as well as the SQL Monitoring plug-in"; the landing page and the
   tooltips in the code name `EM_EXPRESS_BASIC` for the Performance Hub. See
   [Genuine Oracle reports](../usage/genuine-oracle-reports.md).
4. **`java -jar Panorama.war` — resolved.** On the sampler page in the first
   snapshot, although the artefact has been `Panorama.jar` since 2024
   ([Jarbler](../development/jarbler.md)). The second snapshot says `Panorama.jar`.
5. **Menu names in the guide** differ from the generated overview in several
   places ("Special extensions" for "Spec. additions"; "DBA General" / "Oracle
   Parameter" for "Database configuration" / "Init-Parameter"; "DBA/SGA details"
   for "SGA/PGA-Details"; one "Historical" redo log entry where there are two).
   The generated overview is the newer and more authoritative one.
6. **The wiki's menu table was wrong** — "Long-term trend" is not a top-level
   menu, and two top-level menus were missing → corrected in [Panorama](../usage/panorama.md) with
   the old state marked. A second supposed error, "long operations" under the
   SQL area, was withdrawn: the first snapshot's menu had no such entry, the
   second has it ([Long operations](../usage/long-operations.md)).
7. **SQL Monitor:** four recording conditions instead of the three in the 2018
   post; the report is described as an active page with CSS and JavaScript, no
   longer as Flash → [SQL Monitor](../usage/sql-monitor.md).
8. **"More than 100" dragnet aspects** against "140+" in the 2026 talk — ageing
   of the website, not a contradiction ([Dragnet Investigation](../usage/dragnet.md)).
9. **"Tested … beginning with Oracle 11.2"** agrees with the CI matrix; the
   Java requirement agrees with the repository.

## What changed between the snapshots

Compared as extracted text, page by page:

| Page | Change |
|---|---|
| Landing page | idle pooled connections: "10 minutes" → "one hour" |
| Sampler page | start example: `Panorama.war` → `Panorama.jar` |
| Usage guide | only the "Last updated" line; the content is unchanged — "Release 11.4", the differing menu names, the missing parentheses and the TODO sections are still there |
| Menu overview | regenerated; one new entry: "SGA/PGA-Details" / "SQL-Area" / "Long operations" — "Show long running operations from GV$Session_LongOps" |

All three changes correspond to findings of the first ingest.

### State of the open points on 2026-10-06

Rechecked against the published pages and the guide's `.adoc` source:

| Point | State |
|---|---|
| `OEM_MONITOR` "as of DB Release 11.4" (guide 1.1; `.adoc` line 28) | unchanged |
| `OEM_MONITOR` named for "the SQL Monitoring plug-in" (same sentence) | unchanged; the code names no role at the SQL Monitor report link — its tooltip only says an internet connection is required |
| `ALTER SESSION\|SESSION SET EVENTS` (guide 2.2.3; line 161) | unchanged |
| "Special extensions" / "Dragnet investigation" (line 234) | unchanged |
| "DBA General" / "Oracle Parameter" (line 239) | unchanged |
| "DBA/SGA details" (line 243) | unchanged |
| "Redologs" / "Historical" (line 252) | unchanged |
| Two `CREATE INDEX` without closing parenthesis (lines 425, 440) | unchanged |
| Five "TODO: Transfer content from german document" | unchanged |
| "more than 100 considered aspects" (landing page); "over 100" (guide) | unchanged; the code has about 145 dragnet SQL entries (`app/helpers/dragnet/`, commit `0277846f`) |
| Pointer URL `panorama-sampler.html` | **fixed** |
| Idle time, `Panorama.war`, "Long operations" in the menu | fixed on 2026-10-05, still so |

## Impact on the wiki

New pages:

- [Panorama menu overview](../usage/panorama-menu-overview.md) — every menu entry with its purpose and its page
- [Privileges for Panorama](../usage/panorama-privileges.md) — grants for the login user and the sampling user
- [Analysis workflows in Panorama](../usage/panorama-analysis-workflows.md) — the pillars of analysis and how the
  interface is driven
- Menu pages: [Session list](../usage/session-list.md), [Session waits](../usage/session-waits.md), [SQL area](../usage/sql-area.md),
  [Describe object](../usage/describe-object.md), [DB cache usage](../usage/db-cache-usage.md), [Database configuration](../usage/database-configuration.md),
  [Genuine Oracle reports](../usage/genuine-oracle-reports.md)

Updated: [Panorama](../usage/panorama.md), [Panorama Sampler](../usage/panorama-sampler.md), [Panorama operations](../usage/panorama-operations.md),
[SQL Monitor](../usage/sql-monitor.md), [Blocking locks](../usage/blocking-locks.md), [Redo logs](../usage/redo-logs.md), [Session context](../usage/session-context.md),
[SQL plan management](../usage/sql-plan-management.md), [Function-based indexes](../usage/function-based-indexes.md), [Storage reorganisation](../usage/storage-reorganisation.md),
[Audit trail](../usage/audit-trail.md), [Segment statistics](../usage/segment-statistics.md), [SGA memory management](../usage/sga-memory-management.md), [AWR](../usage/awr.md),
[ASH](../usage/ash.md), [Dragnet Investigation](../usage/dragnet.md), [Management pack licensing](../usage/management-pack-licensing.md), [Long operations](../usage/long-operations.md), [Panorama configuration](../development/panorama-configuration.md), [PanoramaConnection](../development/panorama-connection.md),
[Client state and security in Panorama](../development/panorama-client-state-and-security.md), [Panorama Sampler internals](../development/panorama-sampler-internals.md),
[Overview](../overview.md).

## Open questions

- 13 of the 16 screenshots were not viewed; what they show beyond the text is
  not in the wiki.
- The guide refers to a "german document" its TODO sections are to be
  transferred from. It is not among the sources.
- The landing page links a second demo address
  (`panorama-ramm.herokuapp.com`) only in markup that is not displayed; whether
  it still exists was not checked.
- Most menu entries have no page of their own yet
  → [Panorama menu overview](../usage/panorama-menu-overview.md).
