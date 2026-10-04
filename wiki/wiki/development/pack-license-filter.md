---
title: Pack licence filter
type: entity
subtype: component
status: draft
tags: [panorama, architecture, licensing]
created: 2026-10-03
updated: 2026-10-03
sources: [panorama-repository.md]
---

# Pack licence filter

The mechanism by which [[panorama]] guarantees that it reads no
licence-restricted Oracle object without the user's confirmation: a text filter
that every SQL statement passes immediately before execution
(`app/models/pack_license.rb`).

## Summary

The user-visible rule is described in [[management-pack-licensing]]: one of four
licence options is confirmed after login, and functions that would violate it
fail with a message. The implementation is deliberately crude and therefore
complete — it does not depend on each controller action remembering to check
([[panorama-source-code]]).

`PanoramaConnection` calls `PackLicense.filter_sql_for_pack_license(sql)` in
`sql_select_iterator`, `sql_execute_native` and
`exec_plsql_with_dbms_output_result`. Since every other select method funnels
into the iterator, **no statement issued through the regular API bypasses it**.

## Two steps

**1. Rewrite.** If the chosen licence is `:panorama_sampler`, the statement is
handed to `PanoramaSamplerStructureCheck.transform_sql_for_sampler`:

- `gv$Active_Session_History` is first renamed to a `DBA_HIST_…` alias so that
  the next rule catches it.
- Every occurrence of `DBA_HIST_<name>` for which the sampler defines a table or
  view `PANORAMA_<name>` is replaced by `<sampler schema>.PANORAMA_<name>`.
- Occurrences without a sampler counterpart are left as they are.

That is how the same controller code and the same views serve both data sources
— the "transparently in the same way" of [[panorama-sampler]]. The rewrite is
positional string surgery: `DBA_HIST` and `PANORAMA` both have eight characters,
and the code overwrites one with the other in place.

**2. Check.** The (possibly rewritten) statement is searched, upper-cased, for
name fragments of licensed objects:

| Licence chosen | Diagnostics Pack names | Tuning Pack names |
|---|---|---|
| `:diagnostics_and_tuning_pack` | allowed | allowed |
| `:diagnostics_pack` | allowed | **raise** |
| `:panorama_sampler` | **raise** | **raise** |
| `:none` | **raise** | **raise** |

- *Diagnostics Pack fragments:* `DBA_HIST_`, `CDB_HIST_`, `DBA_ADDM_`,
  `DBA_ADVISOR_`, `DBMS_WORKLOAD_REPOSITORY`, `DBMS_ADDM`, `DBMS_ADVISOR`,
  `DBMS_PERF`, `DISPLAY_AWR`, `V$ACTIVE_SESSION_HISTORY`, `X$ASH`, the
  `MGMT$…` views and a few more.
- *Exempt despite the prefix:* `DBA_HIST_SNAPSHOT`, `DBA_HIST_DATABASE_INSTANCE`,
  `DBA_HIST_SEG_STAT`, `DBA_HIST_SEG_STAT_OBJ`, `DBA_HIST_SNAP_ERROR`,
  `DBA_HIST_UNDOSTAT` and their `CDB_` twins, plus Panorama's own
  `DBA_HIST_BLOCKING_LOCKS`.
- *Tuning Pack fragments:* `V$SQL_MONITOR`, `V$SQL_PLAN_MONITOR`,
  `DBMS_SQL_MONITOR`, `DBA_HIST_REPORTS`, `DBMS_AUTO_SQLTUNE`, and the SQL-set
  procedures of `DBMS_SQLTUNE` individually.

A hit raises `PopupMessageException` — "Access denied on table … because of
missing license for Oracle … Pack" — which the user sees as a plain message.

## Why the sampler's "hard edge" exists

[[management-pack-licensing]] notes that under the sampler option, access to AWR
tables without sampler data fails instead of silently reading AWR. The mechanism
is exactly the combination above: step 1 leaves an unmatched `DBA_HIST_…` name
untouched, step 2 then finds it and raises.

> Conclusion: the set of evaluations usable with the sampler is therefore
> *defined by* the table and view list in `PanoramaSamplerStructureCheck`
> (about 55 definitions). That list is the precise answer to "what does the
> sampler cover" — see [[panorama-sampler-internals]].

## Before the licence is confirmed

On first login the licence in the connect info is forced to `:none`
(`EnvController#set_database`), so the queries of the login itself cannot touch
licensed objects. Only after the database has been read is the pre-selection
derived from `control_management_pack_access`, and the user confirms it on the
next screen. An autonomous database, where the parameter is not set, is treated
as `DIAGNOSTIC+TUNING`.

## Consequences for writing SQL in Panorama

- A comment or a string literal containing `DBA_HIST_` trips the filter just
  like real access — it matches text, not parse trees.
- Evaluations meant to work for all licence types must address AWR by its
  `DBA_HIST_…` names and let the rewrite do the rest; hard-coding
  `Panorama_…` tables breaks the Diagnostics Pack path.
- Tests assert on this behaviour with
  `assert_response_success_or_management_pack_violation`
  ([[panorama-build-test-and-release]]).

## Relationships

- Called from [[panorama-connection]].
- The rewrite targets are created by [[panorama-sampler-internals]].
- The user-facing rule: [[management-pack-licensing]]; the data sources:
  [[awr]], [[ash]].

## Open questions

- `DBMS_PERF` is listed under the Diagnostics Pack and commented out under the
  Tuning Pack with the remark "unclear which pack is really needed". Unresolved
  in the code.
- A block for autonomous databases (`CDB_Hist` instead of `DBA_Hist`) is present
  but commented out with a `TODO`. What is the current handling there?
- Statements run through `exec_clob_plsql_function` and the direct selects during
  login are **not** filtered. The former is used for Oracle's own reports; are
  all of its callers guarded by an explicit licence check?

## Sources

- [[panorama-source-code]]
