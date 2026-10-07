---
title: Panorama Sampler
type: entity
subtype: component
status: draft
tags: [panorama, licensing]
created: 2026-10-01
updated: 2026-10-05
sources: [blog.md, posts/, panorama-repository.md, speakerdeck.md, speakerdeck/, rammpeter.github.io.md, rammpeter.github.io/]
---

# Panorama Sampler

Panorama's own facility for recording session activity and historical performance
data — the substitute wherever [AWR](awr.md) and [ASH](ash.md) may not be used for licensing
reasons.

## Summary

The clearest statement about it comes from [Blog series on locks and serialisation](../sources/blog-locks.md) (2020-10-06):

> "Precondition for using ASH is the Enterprise Edition of Oracle DB and the
> licensing of the Diagnostics Pack. If you don't have licensed Diagnostics Pack
> or you are running Standard or Express Edition, then you can use the similar
> function of Panorama-Sampler to record the session activity. **Panorama
> evaluates both sources (AWR/ASH or Panorama-Sampler) transparently in the same
> way.**"

The last sentence is the decisive one: the evaluations are **the same**. The
sampler is not a stripped-down side feature but an interchangeable data source —
the retrospective lock analysis from [Blocking locks](blocking-locks.md) works with it just as it
does with ASH.

Affected are therefore Standard Edition, Express Edition and any Enterprise
Edition without the Diagnostics Pack ([Blog series on indexing](../sources/blog-indexing.md), 2019-12-27 names the
same purpose).

## What it records beyond AWR

([Blog series on Panorama as a tool](../sources/blog-panorama-the-tool.md), 2017-11-17) In addition to Oracle's AWR, the sampler
can also record historical information for:

- the size evolution of tablespace objects
- the occupancy of the DB cache by objects
- detailed information about blocking lock scenarios

> None of these is part of the AWR recordings. The sampler is therefore not only
> a licence-free replacement but in these three respects a genuine addition —
> see [SGA memory management](sga-memory-management.md) for the DB cache case.

It also feeds the condensed long-term data → [Long-term trend analysis](long-term-trend-analysis.md).

## How it works

From the source code ([Panorama source repository](../sources/panorama-source-code.md)); details in
[Panorama Sampler internals](../development/panorama-sampler-internals.md).

- **No agent.** Sampling is done by the running Panorama server, which connects
  to each configured database on a schedule. If the server is down, nothing is
  recorded. It requires `PANORAMA_MASTER_PASSWORD` to be set.
- **Storage** is a schema in the sampled database itself, with tables named
  `Panorama_<AWR name>`. Panorama creates and upgrades that schema on its own.
- **Five independent domains**, all off by default: AWR/ASH (default every 60
  minutes, retention 32), object sizes (24 hours / 1000), cache objects (30
  minutes / 60), blocking locks (2 minutes / 60), long-term trend (24 hours /
  3650). Retention in days.
- **ASH sampling** is a database session running a PL/SQL loop that samples once
  per second.
- **"Transparently in the same way"** is implemented by rewriting `DBA_HIST_…`
  names in the SQL to the sampler's tables → [Pack licence filter](../development/pack-license-filter.md).

## Limits, rules and one advantage

From the author's talks of 2022 and 2025 ([Talks on Panorama and the Panorama Sampler](../sources/talks-panorama-and-sampler.md)).

**What the sampler's ASH lacks compared with Oracle's:**

- **No plan line and operation.** The load of a SQL cannot be broken down onto
  the lines of its execution plan — the "DB time" column of the plan view stays
  empty with sampler data.
- **Only top-level SQL**, as shown in `v$Session.SQL_ID`. Recursively executed
  SQL is not reported.
- **No I/O requests and volumes** per sample: reading `v$SesStat` once per second
  and session is too slow.

**What it has that AWR lacked:** the execution plans it records contain the
**access and filter predicates**. Oracle's own AWR did not store them up to
release 21, although the columns have existed since 10g. For the analyses in
[Index access paths](index-access-paths.md) and [Finding skipped index columns](../syntheses/finding-skipped-index-columns.md), which depend on
exactly those columns, the sampler's history is therefore the better source on
older releases.

**RAC:** the sampler records only the instance its connection lands on. Use a
TNS service bound to one node, create one configuration per node, and let all of
them write into the same schema.

**PDB:** user `SYSTEM` in the CDB samples the CDB and all PDBs with one
configuration. Any other user samples only its own container, so one
configuration per PDB is needed. With `SYSTEM`, a separate schema for the
sampler's objects is mandatory.

**Releases:** "11.2 to 21" (2022), "11.2 up to 26ai" (2025); all editions.

**Using the data with other software.** Because the tables mirror the
`DBA_HIST_*` views, synonyms with the original view names can point at them; the
2025 talk prints a PL/SQL block that creates the synonyms for all views that
have a replacement, and deliberately points the rest at a non-existent object.
Scripts written against AWR then run on sampler data "without license
violation".

**AWR views with a replacement** (2025): `gv$Active_Session_History` and
`DBA_Hist_` Active_Sess_History, Cache_Advice, Database_Instance, Datafile,
Enqueue_Stat, FileStatXS, IOStat_Detail, IOStat_Filetype, Log,
Memory_Resize_Ops, OSStat, OSStat_Name, Parameter, PGAStat, Process_Mem_Summary,
Resource_Limit, Seg_Stat, Service_Name, Service_Stat, SGAStat, Snapshot,
SQL_Bind, SQL_Plan, SQLStat, SQLText, StatName, Sysmetric_History,
Sysmetric_Summary, System_Event, SysStat, Tablespace, Tempfile, TempStatXS,
TopLevelCall_Name, UndoStat, WR_Control. The rule stated: every AWR view that
Panorama's own functions use gets a replacement.

## Setting it up and using it

([Panorama's website on GitHub Pages](../sources/rammpeter-github-io.md), sampler page.)

1. **Start the Panorama server with a master password**
   (`PANORAMA_MASTER_PASSWORD`). That adds "Admin login" to the menu "Spec.
   additions" and starts the background threads for sampling.
2. **Log in as admin** and open "Admin" / "Panorama-Sampler config". (The page
   also says the function is "in menu 'Spec. additions'"; the generated menu
   overview puts it under "Admin".)
3. **Add the database:** TNS alias or host, port and SID/service name; user and
   password; optionally a different schema for the sampler's tables — needed for
   a CDB, where you log in with a system account to sample all PDBs.
4. **Per domain** (AWR/ASH, size evolution, cache usage, blocking locks,
   long-term trend) set separately: active or not, period between snapshots,
   retention before housekeeping, and domain-specific settings.

The grants of the sampling user are listed in [Privileges for Panorama](panorama-privileges.md).

**The tables are created deferred, at the first snapshot.** Only after that does
Panorama recognise sampler data at login and offer the choice between three
ways of working: Oracle's AWR (Enterprise Edition with Diagnostics Pack), the
sampler's data, or no historic workload data at all — "but this way Panorama's
functions are strongly reduced" ([Management pack licensing](management-pack-licensing.md)).

**Several master passwords** are possible: each gives its own set of
configurations, and sampling is active only for the set belonging to the
password the server was started with.

**Health check for monitoring tools.**
`http://<server>:8080/panorama_sampler/monitor_sampler_status` returns JSON with
the configured data sources — ID, name, time of the last successful connect,
time of the last error and its message. The HTTP status is 200, or **500 if any
configured source has a persisting error**; meant for Zabbix, Nagios, Icinga and
the like. It is the only sampler action reachable without authentication
([Panorama Sampler internals](../development/panorama-sampler-internals.md)).

**Further limits named on the website** beyond those from the talks: in the
sampled segment statistics 'gc cr blocks served', 'gc current blocks served' and
'chain row excess' are missing, because `v$SegStat` does not supply them
([Segment statistics](segment-statistics.md)). The ASH replacement samples once per second for
short-term storage ("currently until next snapshot") and keeps every tenth
second for the long term — the same two grains as Oracle's ([ASH](ash.md)).

**The synonym script** for foreign AWR scripts is printed on the website as
well. One detail not noted from the talk: `GV$ACTIVE_SESSION_HISTORY` becomes a
synonym, while `V$ACTIVE_SESSION_HISTORY` is created as a **view** that filters
the sampler's table to the current instance.

### Differences to the other sources

- **One more replaced view.** The website's list has 38 entries; compared with
  the list from the 2025 talk below it additionally contains
  `DBA_Hist_Sys_Time_Model`. Either the talk slide omitted it or it was added
  since.
- ~~**`java -jar Panorama.war`** in the website's start example is outdated; the
  artefact is `Panorama.jar` ([Jarbler](../development/jarbler.md)).~~ Corrected on the website the same
  day: the version published 2026-10-05 13:03 UTC says `Panorama.jar`.

## Relationships

- A component of [Panorama](panorama.md).
- Takes the place of [AWR](awr.md) and [ASH](ash.md) → [Management pack licensing](management-pack-licensing.md).
- Underpins [Blocking locks](blocking-locks.md), [Long-term trend analysis](long-term-trend-analysis.md) and the
  dashboard described in [Panorama](panorama.md).
- Views that exist only with sampler data: historic [DB cache usage](db-cache-usage.md), lock
  history in [Blocking locks](blocking-locks.md), object size evolution
  ([Panorama menu overview](panorama-menu-overview.md)).

## Open questions

- ~~How does the sampler work technically — sampling interval, storage
  location, retention period?~~ Answered 2026-10-03, see *How it works*.
- ~~Where are its limits compared with real ASH?~~ Largely answered 2026-10-04
  by the talks, see *Limits, rules and one advantage*. Remaining: narrowed down: an evaluation
  works with the sampler exactly if every `DBA_HIST_…` view it reads has a
  counterpart among the sampler's roughly 55 tables
  ([Panorama Sampler internals](../development/panorama-sampler-internals.md)). A list of the evaluations that therefore do
  *not* work has still not been drawn up.

## Sources

- [Blog series on locks and serialisation](../sources/blog-locks.md)
- [Blog series on Panorama as a tool](../sources/blog-panorama-the-tool.md)
- [Blog series on indexing](../sources/blog-indexing.md)
- [Panorama source repository](../sources/panorama-source-code.md)
- [Talks on Panorama and the Panorama Sampler](../sources/talks-panorama-and-sampler.md)
- [Panorama's website on GitHub Pages](../sources/rammpeter-github-io.md)
