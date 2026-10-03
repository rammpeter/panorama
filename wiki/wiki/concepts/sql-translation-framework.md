---
title: SQL Translation Framework
type: concept
status: draft
tags: [execution-plan, oracle]
created: 2026-10-01
updated: 2026-10-02
sources: [blog.md, posts/]
---

# SQL Translation Framework

A feature from release 12.1 that swaps the **complete SQL text** for a
replacement text before processing. Actually intended for migrating foreign
dialects, but according to [[blog-bind-variables]] (2017-09-13) "a sharp weapon
for performance troubleshooting" — and one of the more hidden features of the
database.

## What distinguishes it from SQL patches

[[sql-plan-management]] only reaches as far as the optimizer hint. The
Translation Framework replaces the whole text. That makes it possible to fix
**any** problem solvable by changing the SQL text — without touching the
application that executes the SQL:

- add missing JOIN or WHERE conditions
- factor parts out into a WITH clause
- rewrite the formulation entirely

## The two limits

Only two things have to stay stable:

1. **The result structure** — number, order and types of the result columns.
2. **The bind variables** — number, alias, order and types.

## The procedure

[[panorama]] generates the full script via the button "Generate SQL-Translation"
in the current and the historical SQL detail view; all you have to enter is the
adjusted SQL text. The generated sequence:

1. **As SYS:** `GRANT CREATE SQL TRANSLATION PROFILE` and `GRANT ALTER SESSION`
   to the executing user.
2. **As that user:** `DBMS_SQL_TRANSLATOR.CREATE_PROFILE`, then
   `REGISTER_SQL_TRANSLATION` with the original and the replacement text.
3. **As SYS:** an `AFTER LOGON ON DATABASE` trigger that sets
   `SQL_TRANSLATION_PROFILE` for the affected user and activates event 10601
   (level 32).

To remove it, the same route in reverse: drop the trigger,
`DEREGISTER_SQL_TRANSLATION`, and drop the profile only when no translations are
attached to it any more (to be checked in `DBA_SQL_TRANSLATIONS`).

**The practical hurdle:** the translation only takes effect after a **new
logon** — restart the application or reset the session pool. The author
explicitly notes a gap: the event can be set subsequently in a running session
via `DBMS_SYSTEM.SET_EV`, but *"I did not found a solution for setting
SQL_TRANSLATION_PROFILE … in a running session"*.

## In Panorama

Existing translations under "SGA/PGA-details" / "SQL plan management" / "SQL
translations". If a SQL results from a translation, the detail view points this
out — the same precaution as with SQL patches, so that nobody misreads the plan.

## Relationships

- The more powerful but more involved counterpart to the SQL patch from
  [[sql-plan-management]].
- A way to replace literals with bind variables after the fact →
  [[bind-variables-and-cursor-sharing]], and the gentler alternative to the
  rejected [[cursor-sharing-force-is-no-substitute]].
- The LOGON trigger is the same mechanism that holds surprises in other
  environments → [[logon-trigger]].

## Open questions

- The author's gap is unresolved: how do you set `SQL_TRANSLATION_PROFILE` in a
  **running** session?
- What overhead does the translation cause per parse?
- Does the feature need an additional licence? The source says nothing about it —
  unlike for the SQL patch, where it clarifies the matter explicitly.

## Sources

- [[blog-bind-variables]]
