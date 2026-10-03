---
title: Gradual password rollover
type: concept
status: draft
tags: [audit, security, oracle]
created: 2026-10-01
updated: 2026-10-02
sources: [blog.md, posts/]
---

# Gradual password rollover

From Oracle 19.12 the **old and the new password** can both serve for logging in
for a limited period. According to [[blog-audit-trail]] (2024-03-25) "a great and
long-awaited feature" that substantially lowers the barrier to changing
passwords.

## The hurdle in practice

For the change to be completed you have to know **which clients are still using
the old password**. Otherwise the rollover period ends and the forgotten clients
fail.

The only way known to the author:

1. Use **unified auditing**.
2. Create a policy for the `LOGON` action.
3. Check the logon records for the keyword **`VERIFIER=12C-OLD`** in the column
   `AUTHENTICATION_TYPE`.

> "The only way of monitoring the use of old passwords known to me so far is …"
>
> The qualification is taken over verbatim — it is the way known to the author,
> not demonstrably the only one.

## The overview query

The post joins three sources into a list of all users currently in a rollover
phase (`Account_Status LIKE '%ROLLOVER%'`):

- `DBA_USERS` — status, date of the password change, profile, last login
- `DBA_PROFILES` — the resource `PASSWORD_ROLLOVER_TIME`
- `UNIFIED_AUDIT_TRAIL` — the number and time range of logins with the old
  password, plus, per attribute, the count of distinct values and one example
  value (OS user, host, terminal, instance, client program, DB link info)

From these it computes `Rollover_Expiration_Date` and
`Remaining_Days_for_Rollover` — that is, how much time is left.

**One detail that makes the query robust:** `PASSWORD_ROLLOVER_TIME` is present
in `DBA_PROFILES` in **seconds or days** depending on the case. The query
therefore checks for a pure number via `REGEXP_LIKE` and converts values above 60
as seconds — with a reference to Doc ID 2815172.1.

> The pattern "count distinct values per column plus one example value" is
> particularly useful here: if a user shows `UserHost_Cnt = 1`, exactly one client
> is left and you immediately know which.

In [[panorama]] a click on the number in the column "Logons with old password"
leads to the individual audit records of that user.

## Relationships

- Requires unified auditing → [[audit-trail]],
  [[unified-audit-trail-operations]].
- An evaluation that serves operations rather than performance — like
  [[logon-trigger]], a case where the blog touches the DBA side.

## Open questions

- Is there by now a way without unified auditing? The author phrases it
  deliberately cautiously.
- What happens to sessions still using the old password when the rollover period
  expires — does only the next connect fail, or does the existing connection
  break?

## Sources

- [[blog-audit-trail]]
