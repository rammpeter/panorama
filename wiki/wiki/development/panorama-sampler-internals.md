---
title: Panorama Sampler internals
type: entity
subtype: component
status: draft
tags: [panorama, architecture, sampling]
created: 2026-10-03
updated: 2026-10-05
sources: [panorama-repository.md, speakerdeck.md, speakerdeck/, rammpeter.github.io.md, rammpeter.github.io/]
---

# Panorama Sampler internals

How the [Panorama Sampler](../usage/panorama-sampler.md) is implemented: a scheduler job and worker threads
inside the Panorama server process, a self-maintained schema in each target
database, and PL/SQL that does the actual sampling there.

## Summary

The sampler has no agent on the database host and no process of its own. A
running Panorama instance connects to each configured database on a schedule and
executes SQL and PL/SQL that copies the current state of `V$` views into tables
of a dedicated schema. Stop the Panorama server and sampling stops
([Panorama source repository](../sources/panorama-source-code.md)).

It is only active if `PANORAMA_MASTER_PASSWORD` is set
([Panorama configuration](panorama-configuration.md)): the job is not scheduled otherwise, and the
password encrypts the stored database credentials.

## The five domains

`PanoramaSamplerConfig` holds, per target database, the connection data, the
schema owner and independent settings for five domains. Defaults from
`app/models/panorama_sampler_config.rb`:

| Domain | What | Default cycle | Default retention |
|---|---|---|---|
| `AWR_ASH` | AWR-like snapshots and ASH-like session samples | 60 minutes | 32 |
| `OBJECT_SIZE` | size of segments over time | 24 hours | 1000 |
| `CACHE_OBJECTS` | DB cache occupancy by object | 30 minutes | 60 |
| `BLOCKING_LOCKS` | blocking lock scenarios | 2 minutes | 60 |
| `LONGTERM_TREND` | condensed load data → [Long-term trend analysis](../usage/long-term-trend-analysis.md) | 24 hours | 3650 |

Retention is in days — stated in the code for the long-term trend, assumed for
the others. All domains are off by default. Further AWR/ASH settings: one-second
ASH samples are kept for 3 hours, and a SQL is only recorded from 2 executions
and 10 ms runtime upward.

The long-term trend has a selectable source: Oracle's own ASH
(`:oracle_ash`, the default — which needs the Diagnostics Pack) or the sampler's.

## Control flow

**`PanoramaSamplerJob`** (`app/jobs/panorama_sampler_job.rb`) reschedules itself
to the next multiple of the smallest active cycle across all configurations, at
least hourly and never below one minute. On each run it checks, per
configuration and domain, whether the wall clock sits on that domain's cycle
boundary and the previous snapshot is old enough, and if so calls
`WorkerThread.create_snapshot`.

On the **first run after server start** it behaves differently: it resets the
structure-check flags and starts the ASH daemon immediately, aligned to the
previous regular snapshot boundary, so that ASH sampling resumes without waiting
for the next snapshot.

**`WorkerThread`** (`app/models/worker_thread.rb`) runs each piece of work in a
new Ruby thread. Its constructor builds a connect info hash from the sampler
configuration — with the master password as the decryption salt, licence `:none`
and a query timeout of one minute more than the AWR cycle — and pins it to the
thread, exactly as a web request would ([PanoramaConnection](panorama-connection.md)). The sampler
therefore shares pool, error handling and [Pack licence filter](pack-license-filter.md) with the GUI.

Per snapshot (`create_snapshot_internal`):

1. A semaphore per configuration and domain prevents overlapping runs. If one is
   set, the thread asks the database whether a session with the same module and
   action is really still active; if not, the semaphore is treated as stale.
2. Structure check (once per server start).
3. Sampling.
4. Housekeeping: delete beyond retention.
5. On any error: destroy the connection, force a structure check, housekeeping
   **with `SHRINK SPACE`**, then retry the sampling once. The retry exists to
   recover from a full tablespace quota.

Once a week `check_analyze` gathers statistics on sampler tables whose statistics
are older than seven days and shrinks their indexes.

Errors are stored on the configuration object and shown in the sampler's status
view.

## The schema is self-maintaining

`PanoramaSamplerStructureCheck` (2,100 lines, mostly declarations) contains the
expected structure as Ruby data: a `TABLES` array of about 55 table definitions
with columns, primary keys and indexes, and a `VIEWS` array of about ten. On
each check it compares that with the dictionary and issues the DDL needed to
create or alter tables, columns, keys, indexes and views.

Consequences:

- **There is no installation step and no migration script.** A new Panorama
  release with a changed structure upgrades the schema at the first snapshot
  after start.
- Tables are named `Panorama_<AWR name>` (`Panorama_Snapshot`,
  `Panorama_SQLStat`, `Panorama_Seg_Stat` …), mirroring `DBA_HIST_<name>`. This
  naming is what the SQL rewrite in the [Pack licence filter](pack-license-filter.md) relies on. Some
  are `Internal_…` tables with a `Panorama_…` view on top.
- **The list of tables is the exact scope of the sampler.** An AWR view with no
  counterpart here is unavailable under the sampler option.

## PL/SQL: package or anonymous block

The sampling logic is PL/SQL kept as Ruby strings in
`app/helpers/panorama_sampler/`: `Panorama_Sampler_Snapshot`,
`Panorama_Sampler_ASH`, `Panorama_Sampler_Block_Locks` and a small helper
package. Placeholders (`PANORAMA_OWNER`, `PANORAMA_VERSION`, a compile timestamp)
are substituted at deploy time; from 18c `DBMS_LOCK.SLEEP` becomes
`DBMS_SESSION.SLEEP`.

How it runs depends on a privilege:

- If the sampling user has **`SELECT ANY TABLE`**, the code is installed as
  packages in the schema and called.
- Otherwise the same code is sent as an **anonymous PL/SQL block** each time.

The reason is in a code comment: `V$` views granted through a role are not
accessible inside a stored package; they are from an anonymous block. `SYSTEM`
is forced to the anonymous route (tested, per the comment, on 18.3 EE and
18.4 XE), `SYS` to the package route.

## The ASH daemon

ASH sampling is one long PL/SQL call, `Run_Sampler_Daemon`, that occupies a
database session and a Ruby thread until shortly after the next snapshot time:

- It samples active sessions **once per second**, sleeping to the next full
  second each time.
- Samples are written to the database in blocks every **ten seconds**.
- Hand-over between consecutive daemons is coordinated at a ten-second boundary:
  the new daemon signals its predecessor, which finishes its current block and
  ends.
- The one-second samples are kept for the configured hours; a ten-second
  subset is retained for the snapshot retention, as with Oracle's ASH. (Read
  from variable names and comments, not traced line by line.)

`sql_execute_native` deliberately sets no query timeout, because this call is
supposed to run for a whole snapshot cycle.

> Conclusion: with ASH sampling active, each sampled database permanently holds
> one Panorama session in a PL/SQL loop. That is the cost of having no agent.
> Two Panorama instances sampling the same database is a foreseen mistake: the
> job logs a warning when a snapshot turns out to have been started already.

## Configuration storage

The configurations are an array of hashes in the
[client info store](panorama-client-state-and-security.md) under a key derived
from the master password; database passwords in it are encrypted with the master
password as salt. Changing the master password therefore orphans the stored
configuration. Export and import as JSON exist and require admin authentication
(changelog 2026-09-01).

At login the GUI looks for schemas containing sampler tables
(`panorama_sampler_schemas`) and remembers the one to use; with several, the one
named in the sampler configuration for this DBID wins.

## The picture the author draws

The architecture slide of the 2022 and 2025 talks
([Talks on Panorama and the Panorama Sampler](../sources/talks-panorama-and-sampler.md)) shows the same split as the code and adds the
data source of each domain:

| Domain | Executed as | Reads | Writes |
|---|---|---|---|
| AWR snapshot | PL/SQL | `v$` views, and the one-second ASH samples | snapshot tables; ASH samples condensed to 10 seconds |
| ASH daemon | PL/SQL, running until the end of the snapshot cycle | `v$` views | ASH samples at 1 second |
| Long-term trend | PL/SQL | the 10-second ASH samples | `Panorama_Longterm_Trend` |
| Object size | SQL | `DBA_Segments` | `Panorama_Object_Sizes` |
| DB cache | SQL | `v$BH` | `Panorama_Cache_Objects` |
| Blocking locks | PL/SQL | `v$Lock` and others | `Panorama_Blocking_Locks` |

The talks also state the design rule this wiki had inferred: the tables are
structurally identical to the AWR views of release 19 or 23, with the same name
suffix — and the limits of the ASH replacement, recorded in
[Panorama Sampler](../usage/panorama-sampler.md).

## What the website adds

([Panorama's website on GitHub Pages](../sources/rammpeter-github-io.md), sampler page.)

- **A health endpoint.** `panorama_sampler/monitor_sampler_status` returns the
  state of all configured sources as JSON, with HTTP 500 if any has a persisting
  error. In the code (commit `e8993893`) it is the one action of
  `PanoramaSamplerController` exempt from authentication
  (`app/controllers/panorama_sampler_controller.rb`: "The only action that can be
  called without authentication") and is listed among the exceptions in
  `application_controller.rb`.
- **The grants** of the sampling user, including the reason for the
  package-or-anonymous-block switch in the author's own words
  → [Privileges for Panorama](../usage/panorama-privileges.md). It confirms the code comment quoted above.
- **Tables are created at the first snapshot**, not when the configuration is
  saved — the user-visible side of the self-maintaining schema.
- **One thread per snapshot** of a configured database ("own thread for each
  snapshot").
- The diagram `Panorama-Sampler.png` on the website (viewed) is the same picture
  as in the talks, described in *The picture the author draws*.

## Relationships

- The feature as users see it: [Panorama Sampler](../usage/panorama-sampler.md); the licence option it
  backs: [Management pack licensing](../usage/management-pack-licensing.md).
- Uses [PanoramaConnection](panorama-connection.md); made transparent by the
  [Pack licence filter](pack-license-filter.md).
- Part of [Panorama architecture](panorama-architecture.md).
- The Oracle side it imitates: [AWR](../usage/awr.md), [ASH](../usage/ash.md); one of its extras:
  [Blocking locks](../usage/blocking-locks.md).

## Open questions

- The PL/SQL bodies were only skimmed. Which `V$` views does each snapshot read,
  and where does it deviate from what AWR stores?
- ~~In RAC: how are the other instances sampled?~~ Answered 2026-10-04 by the
  talks ([Talks on Panorama and the Panorama Sampler](../sources/talks-panorama-and-sampler.md)): not at all by one configuration. One
  configuration per node, each through a node-bound TNS service
  → [Panorama Sampler](../usage/panorama-sampler.md).
- Retention units for the non-trend domains are assumed, not verified.

## Sources

- [Panorama source repository](../sources/panorama-source-code.md)
- [Talks on Panorama and the Panorama Sampler](../sources/talks-panorama-and-sampler.md)
- [Panorama's website on GitHub Pages](../sources/rammpeter-github-io.md)
