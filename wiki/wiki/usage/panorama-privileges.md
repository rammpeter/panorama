---
title: Privileges for Panorama
type: concept
status: draft
tags: [panorama, security, privileges]
created: 2026-10-05
updated: 2026-10-05
sources: [rammpeter.github.io.md, rammpeter.github.io/, panorama-repository.md]
---

# Privileges for Panorama

Which grants a database user needs — the user you log in to [[panorama]] with,
and the separate user [[panorama-sampler]] records with.

## The login user

([[rammpeter-github-io]], landing page.) The minimum is one system privilege;
everything else unlocks a particular function.

| Grant | What it is needed for |
|---|---|
| `SELECT ANY DICTIONARY` | Access to the `DBA_…` views. **The minimum requirement to run Panorama.** |
| `OEM_MONITOR` | From Oracle 11.2.0.4: generating Oracle's built-in AWR and ASH reports → [[genuine-oracle-reports]] |
| `SELECT_CATALOG_ROLE` | Results from `DBMS_METADATA.GET_DDL`; and required altogether on an Autonomous Database in the Oracle cloud |
| `EM_EXPRESS_BASIC` | Results from `DBMS_PERF` — the Performance Hub report → [[genuine-oracle-reports]] |
| `ANALYZE ANY` | Results from `DBMS_SPACE.SPACE_USAGE`; alternatively the `ANALYZE` privilege on the particular object → [[storage-reorganisation]] |
| `SELECT ANY TRANSACTION` | Selecting from `Flashback_Transaction_Query` |
| `ADVISOR` | Running the SQL Tuning Advisor through `DBMS_SQLTUNE` and reading its result |
| `CREATE ANY SQL PROFILE` | Creating SQL profiles when using the SQL Tuning Advisor → [[sql-plan-management]] |

**Non-admin users on an Autonomous Database** in OCI need four more for "some
minor functions":

| Grant | Purpose |
|---|---|
| `SELECT ON V$DIAG_ALERT_EXT` | read the alert log view |
| `READ ON SYS.DBMS_LOCK_ALLOCATED` | read access |
| `READ ON gv$BH` | read access — the buffer cache content, see [[db-cache-usage]] |
| `AUDIT_VIEWER` | read the unified audit view → [[audit-trail]] |

What the code adds ([[panorama-source-code]], read at commit `e8993893`):

- The login check raises "Your user needs SELECT ANY DICTIONARY ( and
  SELECT_CATALOG_ROLE if autonomous DB) or equivalent rights to login to
  Panorama!" (`app/models/panorama_connection.rb`).
- Tooltips of the report buttons accept **`DBA` as an alternative** to
  `OEM_MONITOR` and to `EM_EXPRESS_BASIC`.
- Reading server trace files (`gv$Diag_Trace_File`,
  `gv$Diag_Trace_File_Contents`) asks for `SELECT_CATALOG_ROLE`
  (`app/controllers/dba_controller.rb`) — a use of the role the website's table
  does not mention.

> Conclusion: privileges and licences are two separate gates. A grant from this
> table makes a function *technically* callable; whether it *may* be called is
> decided by the pack licence chosen at login
> ([[management-pack-licensing]]). The AWR report needs both `OEM_MONITOR` and
> the Diagnostics Pack; the SQL Tuning Advisor needs both `ADVISOR` and the
> Tuning Pack.

## The sampling user

([[rammpeter-github-io]], sampler page.) Unlike the login user, it writes —
into its own schema in the sampled database.

- `CONNECT`, `RESOURCE`, `CREATE VIEW` — to create tables and views
- enough quota on its default tablespace
- `SELECT ANY DICTIONARY`
- `EXECUTE ON DBMS_LOCK`, granted by `SYS` — for `DBMS_LOCK.SLEEP` in the
  one-second session sampler. **Only up to release 12.2**; from 18 Panorama uses
  `DBMS_SESSION.SLEEP`.
- the right to create objects in another schema, if the connecting user and the
  schema holding the sampler's objects differ (as they must when `SYSTEM`
  samples a container database, see [[panorama-sampler]])

**Optional: `SELECT ANY TABLE`.** With it, the sampling code is installed as
PL/SQL packages; without it, the same code is sent as a larger anonymous block at
every snapshot, "that may result in a bit more network traffic". The reason given:
`V$` views cannot be selected from inside a package when the right comes through
the role `SELECT_CATALOG_ROLE`, because roles are not propagated to stored
PL/SQL. The mechanism is described in [[panorama-sampler-internals]].

## Contradictions

- **Release of `OEM_MONITOR`.** The usage guide on the same website says the
  privilege is required "as of DB Release 11.4". There is no such release; the
  landing page's "11.2.0.4" is taken as correct and the guide's as a slip. Not
  confirmed by the author.
- **`OEM_MONITOR` is called a "system privilege"** in the guide and a "grant" on
  the landing page; the code's tooltips call it a role, which is what it is.

## Relationships

- The tool: [[panorama]]; running it: [[panorama-operations]].
- The second gate: [[management-pack-licensing]], enforced by
  [[pack-license-filter]].
- What a restricted user sees in a multitenant database:
  [[pluggable-databases]].

## Open questions

- No source maps *every* function to the grant it needs; the website's table
  says "some particular functions". The trace file case shows the table is not
  complete.
- Is `SELECT_CATALOG_ROLE` a substitute for `SELECT ANY DICTIONARY`? One error
  message in the code (`env_controller.rb`) offers them as alternatives ("…
  `SELECT ANY DICTIONARY` or `SELECT_CATALOG_ROLE`"), the website names the
  former as the minimum.

## Sources

- [[rammpeter-github-io]]
- [[panorama-source-code]]
