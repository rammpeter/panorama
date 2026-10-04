---
title: LOGON trigger
type: concept
status: draft
tags: [session, oracle, cloud]
created: 2026-10-01
updated: 2026-10-02
sources: [blog.md, posts/]
---

# LOGON trigger

An `AFTER LOGON ON DATABASE` trigger is the standard way to give every new
session something — a setting, a profile, a log entry. But it can silently fail
to fire.

## The case

([[blog-sessions-and-connections]], 2025-04-01) A simple LOGON trigger that works
on several databases does nothing in one environment:

- The `CREATE` ran without errors, the trigger **exists and is enabled**.
- Nothing happens on logon — no exception, and the table the trigger was supposed
  to create does not appear.
- Independent of the creator; tested with SYS and with a privileged user.

Environment: Oracle Exadata Database Service on Dedicated Infrastructure in the
OCI cloud, version 19.25, with Database Vault activated.

## The cause

The underscore parameter **`_system_trig_enabled`** controls whether existing
LOGON triggers fire on logon. In the database in question it was set to `FALSE`.

> The actual lesson is the **failure pattern**: a trigger that is valid and
> enabled but does not fire, and does so without any message. All the obvious
> checks — existence, status, privileges, compilation errors — come up empty,
> because none of them sees the parameter.

The author explicitly credits Sean Scott for the hint.

## Why this page is here

Several methods in this wiki depend on a LOGON trigger and would fail without an
error message in such an environment:

- [[sql-translation-framework]] — the translation is activated via a LOGON
  trigger that sets `SQL_TRANSLATION_PROFILE`.
- The 2021 route for linking audit trail and ASH → [[audit-trail]].
- Any form of giving sessions context from outside → [[session-context]].

## Open questions

- Why was the parameter set in that environment? The source states the fact
  without giving a reason from Oracle. Is it connected to Database Vault, to the
  Exadata Service, or was it an individual decision?
- Can the parameter be changed at all in such a managed service?
- Are there further environments (Autonomous Database?) in which LOGON triggers
  fail just as silently?

## Sources

- [[blog-sessions-and-connections]]
