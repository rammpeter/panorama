---
title: Audit trail
type: concept
status: draft
tags: [audit, security, oracle]
created: 2026-10-01
updated: 2026-10-02
sources: [blog.md, posts/]
---

# Audit trail

Oracle's record of who logged in and what they did. In two generations: the
**standard audit trail** (`DBA_AUDIT_TRAIL`, including fine grained auditing) and
the **unified audit trail** (`UNIFIED_AUDIT_TRAIL`). For performance analysis it
is above all the source of information that appears nowhere else.

## The gap to ASH

The central annoyance ([[blog-audit-trail]], 2021-01-05):

| Source | Session identifier |
|---|---|
| audit trail | `AudSID` |
| [[ash]] | SID + `Serial#` |

Both identifiers appear in `V$SESSION` — so **as long as the session lives** they
can be joined. But: the `AudSID` does not appear in ASH, and SID plus `Serial#`
do not appear in the audit trail. Once the session has ended, the link is lost.

### The detour via the Client_Identifier (2021)

The LOGOFF records of the audit trail also log — with `AUDIT SESSION` active —
the `Client_Identifier` from `V$SESSION`. If you fill that with the information
you want, it can later be read from `DBA_AUDIT_TRAIL.Client_ID`. A
[[logon-trigger]] does the job:

```sql
CREATE OR REPLACE TRIGGER Client_ID AFTER LOGON ON DATABASE
BEGIN
  sys.DBMS_SESSION.Set_Identifier('SID = '||DBMS_DEBUG_JDWP.CURRENT_SESSION_ID||
                                  ', Serial# = '||DBMS_DEBUG_JDWP.CURRENT_SESSION_SERIAL);
END;
/
```

> The detail the comment in the original explains: `DBMS_DEBUG_JDWP` is used
> instead of `SYS_CONTEXT` — because only there can the `Serial#` be obtained.

### The direct route with unified auditing (addendum 2025-02)

```sql
AUDIT CONTEXT NAMESPACE USERENV ATTRIBUTES SID;
```

The result appears in the column `Application_Contexts` of
`UNIFIED_AUDIT_TRAIL`, for instance as `(USERENV,SID=55);`.

> **The trigger route is therefore superseded for unified auditing.** It remains
> correct for the standard audit trail and is documented here as its solution —
> not as an equivalent alternative.

## As a source for analysis

The audit trail answers questions for which ASH is too coarse — above all
excessive logons, because establishing a connection is not a SQL activity and is
therefore absent from ASH. In [[panorama]] (menu "DBA general" / "Audit Trail"):
filter on `Action = LOGON`, group by minute, display as a chart — this is how the
author, in the example, attributes 106 logons per minute to a machine, a database
user and an OS user. See [[short-lived-sessions]].

## Evaluation in Panorama

([[blog-audit-trail]], 2023-09-21) Three menu entries under "DBA General" /
"Audit Trail":

- **"Auditing rules"** — the current configuration and the rules for standard,
  fine grained and unified auditing. The sensible entry point: first see *what*
  is being logged at all.
- **"Standard audit trail"** — depending on the chosen grouping, individual
  records or counts grouped by time for the top x among OS and database users,
  machines and actions. The column values are links for refining.
- **"Unified audit trail"** — following the same pattern.

Three links with a value of their own: a `SessionID` shows all records of that
session; a "Client machine" is **resolved via DNS** and lists the currently
connected sessions of that machine; an object name leads to the object details.

## Relationships

- Fills a gap in [[ash]] — see [[short-lived-sessions]].
- The linking trick depends on [[logon-trigger]] and therefore on its pitfalls.
- Operations and performance of the unified audit trail:
  [[unified-audit-trail-operations]].
- The only route to rollover monitoring: [[gradual-password-rollover]].

## Open questions

- What overhead does active auditing create on a heavily loaded system? None of
  the posts quantifies that.
- Can the gap to ASH also be closed in the other direction — getting the
  `AudSID` into ASH?

## Sources

- [[blog-audit-trail]]
- [[blog-sessions-and-connections]]
