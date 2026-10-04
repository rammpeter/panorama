---
title: PanoramaConnection
type: entity
subtype: component
status: draft
tags: [panorama, architecture, session]
created: 2026-10-03
updated: 2026-10-03
sources: [panorama-repository.md]
---

# PanoramaConnection

The class through which every SQL statement of [[panorama]] reaches Oracle
(`app/models/panorama_connection.rb`). It owns the connection pool, binds one
connection to the executing thread and offers the small SQL API the controllers
use.

## Summary

`PanoramaConnection` does what ActiveRecord's connection handling normally does,
but for an open-ended set of target databases chosen at runtime
([[own-connection-pool-outside-activerecord]]). It reuses one piece of the
`oracle_enhanced` adapter — the `JDBCConnection` class — and bypasses the rest
([[panorama-source-code]]).

## Thread-local state

`ThreadLocalStorage` (`app/models/thread_local_storage.rb`) is the only place
that touches `Thread.current`. Three keys:

| Key | Content |
|---|---|
| connect info | Hash with URL parts, user, encrypted password, salt, privilege, query timeout, chosen licence, sampler schema, controller and action name |
| connection object | the `PanoramaConnection` in use by this thread |
| app-info flag | whether `DBMS_APPLICATION_INFO` was set for this request |

The connect info is set at the start of each request and by each sampler thread;
everything else follows lazily from it. Because Puma reuses threads, the state is
reset at the end of every request.

## The pool

A class-level array guarded by one mutex.

- **Lookup.** A free pooled connection is reused if JDBC URL, user **and the
  hash of the password** match. The password check prevents a request with a
  wrong password from riding on another user's open session.
- **Creation.** Otherwise a new JDBC login. With a TNS alias the first attempt
  uses the alias; if the test query fails, a second attempt uses
  host/port/service resolved from `tnsnames.ora`.
- **Limit.** `MAX_CONNECTION_POOL_SIZE` (default 100) is also Puma's maximum
  thread count. When the pool is full, the oldest idle connection is closed; if
  none is idle, the request waits with exponential backoff (0.2 s to 3.2 s, five
  tries) and then fails with a message to try again later.
- **Release.** At the end of the request the connection is only flagged as
  free — it stays logged in.
- **Ageing.** `ConnectionTerminateJob` closes connections idle for more than an
  hour. Logoff runs in a separate thread because it can block until the TCP read
  timeout.
- **Eviction on error.** Any exception in a controller action destroys the
  connection. Independently, a connection is destroyed after more than ten SQL
  errors in its lifetime, or immediately on `Closed Connection` — to stop
  re-using sessions with a persistent fault such as `ORA-16000`.

## What happens at login

For every new session, in this order:

1. JDBC connect with `cursor_sharing: :exact` (the adapter's default would be
   `FORCE` — see [[bind-variables-and-cursor-sharing]]), network encryption and
   checksum `REQUESTED`, and `v$session.program` set to `Panorama <version>`.
2. `setNetworkTimeout` at **twice the query timeout** — the safety net when a
   connection hangs on the network ([[sql-net-and-firewalls]]).
3. JDBC statement cache enabled, 100 cursors.
4. `ALTER SESSION SET parallel_degree_policy = MANUAL`, to avoid `ORA-12850` on
   RAC ([[parallel-execution]]).
5. `ALTER SESSION SET Time_Zone` to the JVM's default time zone.
6. Outside production only: `Statistics_Level = ALL`.
7. `read_initial_attributes`: version, DBID, edition, block size, RAC flag,
   SID/serial, CDB and container, internal structure sizes from `v$Type_Size`,
   and the clock difference between server and database. Failure here produces
   the message that the user needs `SELECT ANY DICTIONARY`.

These attributes are cached on the connection object and exposed as class
methods (`PanoramaConnection.db_version`, `.rac?`, `.is_cdb?`, `.dbid` …), which
the controllers use for version-dependent SQL.

Per request, `DBMS_APPLICATION_INFO.SET_MODULE('Panorama', '<controller>/<action>')`
is called if the action changed — Panorama practises what [[session-context]]
preaches, and its own sessions are identifiable in `V$SESSION`.

## The SQL API

| Method | Returns |
|---|---|
| `sql_select_iterator(sql)` | lazy object; the query runs on `each`, rows are streamed |
| `sql_select_all(sql)` | array of row hashes |
| `sql_select_first_row(sql)` | one row hash or `nil` |
| `sql_select_one(sql)` | first column of the first row |
| `sql_execute(sql)` | nothing; DML, DDL, `CALL` |
| `exec_clob_plsql_function` | CLOB result of a PL/SQL function, for Oracle's reports |
| `exec_plsql_with_dbms_output_result` | `DBMS_OUTPUT` lines, from 19c |

Conventions that apply to all of them:

- **`sql` is a string, or an array** `[statement, bind1, bind2 …]` with `?`
  placeholders. The placeholders are rewritten to `:A1 … :An`. A `nil` bind
  value raises — conditions on optional parameters must be left out of the SQL
  text instead.
- **Rows are hashes with lower-case keys**, extended by `SelectHashHelper` so
  that `rec.column_name` works. Views and grid definitions rely on that.
- **Streaming.** `iterate_query` is patched into the adapter's `JDBCConnection`:
  it fetches row by row and yields, instead of materialising the result as
  `exec_query` would. Large grids are fed from `sql_select_iterator` directly.
- **Query timeout** from the login dialog is set on each statement.
- **Time zone shift.** `DATE` and `TIMESTAMP` columns are shifted by the
  difference between the session time zone and the database's `SYSDATE` zone,
  unless `convert_tz: false` (changelog 2025-07-02). The sampler turns this off:
  its data is kept in the database server's time zone.
- **Errors are re-raised** with the SQL text and the bind values appended.
- **PL/SQL with binds must use `CALL`**, not `BEGIN … END;` — `exec_update`
  raises otherwise.
- The statement currently running is registered on the connection, so the admin
  view of the pool can show it.

In controllers and tests the same four select methods are available without the
class prefix, via `ApplicationHelper`.

## Relationships

- Part of [[panorama-architecture]].
- Every statement is passed through the [[pack-license-filter]].
- The sampler's threads use the same pool → [[panorama-sampler-internals]].
- The password in the connect info is decrypted per login →
  [[panorama-client-state-and-security]].

## Open questions

- The time zone shift is applied in Ruby after fetching. Do queries that filter
  on time ranges compensate consistently? One sampled action does it by hand
  (`First_Time + client_tz_offset_days`); whether all do was not checked.
- `disconnect_aged_connections` only **logs** connections that are in use for
  longer than twice their query timeout. Can such a connection stay in the pool
  indefinitely if the network timeout does not fire?

## Sources

- [[panorama-source-code]]
