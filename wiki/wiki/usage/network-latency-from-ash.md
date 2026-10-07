---
title: Estimating network latency from ASH
type: concept
status: draft
tags: [network, ash, oracle]
created: 2026-10-01
updated: 2026-10-02
sources: [blog.md, posts/]
---

# Estimating network latency from ASH

> "But what if there is only SQL access to the DB server and no access to the
> client?"
> — [Blog series on sessions, connections and the network](../sources/blog-sessions-and-connections.md), 2025-01-23

Normally you measure network latency with `tnsping`, `ping` or `traceroute` —
from one of the two sides. If you only have SQL access to the database and no
access to the client, a detour via [ASH](ash.md) remains.

## The idea

If an application executes the same very short SQL over and over in a loop, two
things hold:

1. It is a **poor architectural approach** — the network latency hits the
   application runtime in full.
2. Precisely this behaviour permits an **estimate** of the latency.

> The very property that causes the problem makes it measurable — the same
> pattern as in [Short-lived sessions](short-lived-sessions.md).

**The calculation:** the time between two SQL executions minus the average
execution time of the SQL in the database. What remains is the time for a network
round trip plus the client-side preparation (JDBC stack, value binding). The
latter should be constant and small compared with the latency.

The number of executions between two ASH samples comes from the incrementing
`SQL_EXEC_ID`.

## The prerequisites

The source names them explicitly — without them the result is worthless:

- **At least 20 gap-free, consecutive ASH samples** of the same session. Solved
  in the SQL by grouping on `Sample_ID - ROW_NUMBER()`, which starts a new group
  at every gap.
- **The same SQL ID in all samples** — only then is the `SQL_EXEC_ID` counter
  trustworthy as an execution counter.
- **Execution time below one second**, the ASH sampling interval; the
  `SQL_EXEC_ID` must have incremented at every sample. Set in the SQL as a limit
  of 50 ms per execution.

Additionally the query filters out local executions in which the network plays no
role, via `PLSQL_ENTRY_OBJECT_ID IS NULL` and `PLSQL_OBJECT_ID IS NULL`.

## How to read the result

The column `Avg_Network_and_App_Latency_ms` shows the database's idle time
between two calls. From that follows an **upper bound**, not a measurement:

> The network latency for a given client machine is **not greater** than the
> smallest value found — otherwise it would be impossible for the client to
> manage that many remote executions in that time. Depending on the processing
> time at the client, the real latency can be **smaller**.

The author calls the method a *"weak estimation"* himself and points out that
interpreting it requires knowledge of the application's implementation.

## Relationships

- Builds on [ASH](ash.md) and therefore requires [Management pack licensing](management-pack-licensing.md).
- The counterpart to [SQL\*Net and firewalls](sql-net-and-firewalls.md): there the standing connection is
  the problem, here it is the measuring instrument.
- The architecture measured is the same one [Short-lived sessions](short-lived-sessions.md) deals with —
  only without tearing the connection down.
- The query is also stored in [Dragnet Investigation](dragnet.md) in [Panorama](panorama.md).

## Open questions

- How large is the share of client-side preparation actually? The assumption
  "constant and small" is not evidenced.
- Can the method be transferred to applications that execute *different* short
  SQL in sequence? The prerequisite of an identical SQL ID rules that out.

## Sources

- [Blog series on sessions, connections and the network](../sources/blog-sessions-and-connections.md)
