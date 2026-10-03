---
title: Blog series on sessions, connections and the network
type: source
status: maintained
tags: [session, network, oracle]
created: 2026-10-01
updated: 2026-10-02
sources: [blog.md, posts/]
---

# Blog series on sessions, connections and the network

Eight posts from [[rammpeter-blog]] between 2014 and 2025 about the layer that
AWR and ASH only see incompletely: sessions coming into being and passing away,
their context, and the path to the client.

## The posts

| Date | Title | Focus |
|---|---|---|
| 2014-04-28 | Create SQL trace for unique application by DBMS_MONITOR | [[sql-trace]] |
| 2014-06-03 | Monitor/sample values from gv$SesStat in history | [[sampling-session-statistics]] |
| 2014-07-09 | Set script name as module/action in V$Session if SQL*Plus-session starts | [[session-context]] |
| 2017-03-22 | Identify excessive logon/logoff operations with short-running sessions | [[short-lived-sessions]] |
| 2017-06-12 | Common pitfalls using SQL*Net via Firewalls | [[sql-net-and-firewalls]] |
| 2020-10-12 | Cost of dedicated DB session connect/disconnect | [[short-lived-sessions]] |
| 2025-01-23 | Estimate network latency of client connections by evaluation of ASH | [[network-latency-from-ash]] |
| 2025-04-01 | Valid and enabled LOGON trigger does not fire at Exadata Cloud Service | [[logon-trigger]] |

## Key points

**Establishing a connection costs measurably — and ASH does not see it.**
Establishing a database connection is not a SQL activity and therefore does not
appear in AWR or ASH. The author measured it via system load instead:
**building up and tearing down a dedicated session once per second costs roughly
4 % of a CPU core** of the database server (2020-10-12)
→ [[short-lived-sessions]].

**Short-lived sessions are hard to catch.** An ASH sampling interval of one
second is "much too large in most cases" for this. The post of 2017-03-22
therefore supplies a chain of methods — from `DBA_AUDIT_TRAIL` through repeated
queries on `GV$SESSION` to a dedicated PL/SQL package that records a shadow copy
of disappearing sessions → [[short-lived-sessions]].

**Session context is the prerequisite for any attribution.** Without module and
action information in `V$SESSION`, an activity cannot later be attributed to a
process. For SQL*Plus jobs this can be enforced via a `login.sql` instead of
relying on the discipline of whoever wrote the job (2014-07-09)
→ [[session-context]].

**Firewalls kill apparently idle connections.** The client afterwards hangs in a
socket read forever. Oracle's solution is `SQLNET.EXPIRE_TIME` — but **only** in
the `sqlnet.ora` of the RDBMS `ORACLE_HOME`; set in the Grid Infrastructure or on
the client the parameter has **no effect** (2017-06-12)
→ [[sql-net-and-firewalls]].

**Network latency can be estimated from ASH** — if an application executes the
same short SQL in a loop. The very same poor architecture that causes the problem
makes it measurable (2025-01-23)
→ [[network-latency-from-ash]].

**A valid, enabled LOGON trigger can silently fail to fire.** The cause was the
underscore parameter `_system_trig_enabled = FALSE` (2025-04-01)
→ [[logon-trigger]].

**Session statistics of terminated sessions cannot be reconstructed.** Oracle
offers no way to break historical statistic values down to a session that has
ended. The post of 2014-06-03 builds a dedicated sampler with semaphore control
for this → [[sampling-session-statistics]].

## Impact on the wiki

New: [[session-context]], [[sql-trace]], [[short-lived-sessions]],
[[sql-net-and-firewalls]], [[network-latency-from-ash]], [[logon-trigger]],
[[sampling-session-statistics]].

Cross-references added in [[ash]] (limits of the one-second interval),
[[sql-translation-framework]] (whose activation hangs on a LOGON trigger) and
[[audit-trail]].

## Notes on the evidence

**A measurement with its setup disclosed.** The post of 2020-10-12 names the
hardware (4 older Xeon cores, 2.6 GHz), the procedure and the intermediate values
before deriving the 4 % figure. The number is therefore traceable, but tied to
that hardware — placed in context accordingly in [[short-lived-sessions]].

**A deliberately weak estimate.** For the latency estimate the author himself
speaks of a *"weak estimation"* and phrases the result as an upper bound: the
real latency is not *greater* than the smallest value found, but may be smaller.
Carried over as such into [[network-latency-from-ash]].

**A solution from outside.** The author explicitly credits Sean Scott for the
hint about `_system_trig_enabled`.

## Source files

`raw/posts/06-*`, `07-*`, `08-*`, `21-*`, `23-*`, `45-*`, `64-*`, `66-*`
