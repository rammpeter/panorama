---
title: SQL trace
type: concept
status: draft
tags: [session, diagnostics, oracle]
created: 2026-10-01
updated: 2026-10-02
sources: [blog.md, posts/]
---

# SQL trace

The classic `SQL_TRACE=TRUE` does not help in a world with connection pools: the
connection does not belong to one application but, in rotation, to all of them.
What has to be traced is therefore not the *session* but the **context**.

## Tracing by context

`DBMS_MONITOR` takes exactly the information that [Session context](session-context.md) has set
([Blog series on sessions, connections and the network](../sources/blog-sessions-and-connections.md), 2014-04-28). To be switched on as SYSDBA:

```sql
-- for one application, by module name, with bind values
EXEC DBMS_MONITOR.SERV_MOD_ACT_TRACE_ENABLE(service_name => 'SYS$USERS',
       module_name => 'ID_Application = 56', binds => TRUE);
EXEC DBMS_MONITOR.SERV_MOD_ACT_TRACE_DISABLE(service_name => 'SYS$USERS',
       module_name => 'ID_Application = 56');

-- for a session that is already running
EXEC DBMS_MONITOR.SESSION_TRACE_ENABLE(session_id => 2910, serial_num => 3015);
EXEC DBMS_MONITOR.SESSION_TRACE_DISABLE(session_id => 2910, serial_num => 3015);
```

The parameters `waits` and `binds` default to `FALSE`. Which trace configuration
is currently active is shown by `DBA_ENABLED_TRACES`.

**The advantage over tracing a session:** the recording can be switched on
*beforehand*, before the application even runs — you do not have to catch the
session first.

## Consolidating the output

Tracing by module produces **many** trace files, one per affected session. The
utility `trcsess` merges the relevant parts into a single file:

```
trcsess output=osp.trc module='AmosOrder::Gui::Dialogs::OrderEntryDialog'
```

## Relationships

- Requires [Session context](session-context.md) — without module/action there is no filter
  criterion.
- For the optimizer's decision instead of the execution:
  [Optimizer diagnostics](optimizer-diagnostics.md).
- Reading trace files without file system access: also
  [Optimizer diagnostics](optimizer-diagnostics.md) (`GV$DIAG_TRACE_FILE_CONTENTS`); [Panorama](panorama.md) lists
  trace files and their contents.

## Open questions

- What overhead does an active trace cause, particularly with `binds => TRUE`?
- How does `DBMS_MONITOR` tracing behave with RAC across several instances?

## Sources

- [Blog series on sessions, connections and the network](../sources/blog-sessions-and-connections.md)
