---
title: Panorama Sampler
type: entity
subtype: component
status: draft
tags: [panorama, licensing]
created: 2026-10-01
updated: 2026-10-04
sources: [blog.md, posts/, panorama-repository.md, speakerdeck.md, speakerdeck/]
---

# Panorama Sampler

Panorama's own facility for recording session activity and historical performance
data — the substitute wherever [[awr]] and [[ash]] may not be used for licensing
reasons.

## Summary

The clearest statement about it comes from [[blog-locks]] (2020-10-06):

> "Precondition for using ASH is the Enterprise Edition of Oracle DB and the
> licensing of the Diagnostics Pack. If you don't have licensed Diagnostics Pack
> or you are running Standard or Express Edition, then you can use the similar
> function of Panorama-Sampler to record the session activity. **Panorama
> evaluates both sources (AWR/ASH or Panorama-Sampler) transparently in the same
> way.**"

The last sentence is the decisive one: the evaluations are **the same**. The
sampler is not a stripped-down side feature but an interchangeable data source —
the retrospective lock analysis from [[blocking-locks]] works with it just as it
does with ASH.

Affected are therefore Standard Edition, Express Edition and any Enterprise
Edition without the Diagnostics Pack ([[blog-indexing]], 2019-12-27 names the
same purpose).

## What it records beyond AWR

([[blog-panorama-the-tool]], 2017-11-17) In addition to Oracle's AWR, the sampler
can also record historical information for:

- the size evolution of tablespace objects
- the occupancy of the DB cache by objects
- detailed information about blocking lock scenarios

> None of these is part of the AWR recordings. The sampler is therefore not only
> a licence-free replacement but in these three respects a genuine addition —
> see [[sga-memory-management]] for the DB cache case.

It also feeds the condensed long-term data → [[long-term-trend-analysis]].

## How it works

From the source code ([[panorama-source-code]]); details in
[[panorama-sampler-internals]].

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
  names in the SQL to the sampler's tables → [[pack-license-filter]].

## Limits, rules and one advantage

From the author's talks of 2022 and 2025 ([[talks-panorama-and-sampler]]).

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
[[index-access-paths]] and [[finding-skipped-index-columns]], which depend on
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

## Relationships

- A component of [[panorama]].
- Takes the place of [[awr]] and [[ash]] → [[management-pack-licensing]].
- Underpins [[blocking-locks]], [[long-term-trend-analysis]] and the
  dashboard described in [[panorama]].

## Open questions

- ~~How does the sampler work technically — sampling interval, storage
  location, retention period?~~ Answered 2026-10-03, see *How it works*.
- ~~Where are its limits compared with real ASH?~~ Largely answered 2026-10-04
  by the talks, see *Limits, rules and one advantage*. Remaining: narrowed down: an evaluation
  works with the sampler exactly if every `DBA_HIST_…` view it reads has a
  counterpart among the sampler's roughly 55 tables
  ([[panorama-sampler-internals]]). A list of the evaluations that therefore do
  *not* work has still not been drawn up.

## Sources

- [[blog-locks]]
- [[blog-panorama-the-tool]]
- [[blog-indexing]]
- [[panorama-source-code]]
- [[talks-panorama-and-sampler]]
