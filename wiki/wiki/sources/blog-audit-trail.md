---
title: Blog series on the audit trail
type: source
status: maintained
tags: [audit, security, oracle]
created: 2026-10-01
updated: 2026-10-02
sources: [blog.md, posts/]
---

# Blog series on the audit trail

Five posts from [[rammpeter-blog]] between 2021 and 2025 on the audit trail — as
a source for analysis, as an object of operations, and as the only route to a
piece of information Oracle does not otherwise hand out.

## The posts

| Date | Title | Focus |
|---|---|---|
| 2021-01-05 | Link between audit trail and active session history | [[audit-trail]] |
| 2023-09-21 | Evaluate database audit trail with Panorama | [[audit-trail]] |
| 2024-03-25 | Monitor gradual password rollover usage | [[gradual-password-rollover]] |
| 2025-01-17 | Accessing Unified_Audit_Trail is very slow. Why? | [[unified-audit-trail-operations]] |
| 2025-01-28 | Cleanup Unified Audit Trail with dynamic number of rows and oldest timestamp | [[unified-audit-trail-operations]] |

The last two belong together: the second is the permanent solution to the problem
whose one-off fix the first describes.

## Key points

**Audit trail and ASH speak different languages.** The audit trail identifies
sessions via `AudSID`, [[ash]] via SID plus `Serial#`. Both appear in
`V$SESSION` — but **neither** identifier appears in the other source. Once a
session has ended, the information can no longer be joined up (2021-01-05)
→ [[audit-trail]].

**There is a detour, and it has changed.** In 2021 the solution was: a LOGON
trigger writing the SID into the `Client_Identifier` via
`DBMS_SESSION.SET_IDENTIFIER`, which then appears in the LOGOFF records. An
addendum from 2025-02 names the direct route for unified auditing:
`AUDIT CONTEXT NAMESPACE USERENV ATTRIBUTES SID` → [[audit-trail]].

**`UNIFIED_AUDIT_TRAIL` can become unusably slow.** The cause is not the amount
of data in the table but a **second source**: if the database is not writable —
as with Active Data Guard, for instance — Oracle writes audit records into `.BIN`
files in the file system. The view reads both sources (2025-01-17)
→ [[unified-audit-trail-operations]].

**`DBMS_AUDIT_MGMT` can only purge by timestamp, not by size.** Anyone needing
both — a minimum retention *and* a size limit — has to compute the time boundary
themselves. Otherwise you purge far too early outside the peak case
(2025-01-28) → [[unified-audit-trail-operations]].

**Old passwords are only visible through unified auditing.** For gradual password
rollover from 19.12 onwards, the author knows of no other way to determine who is
still using the old password than the keyword `VERIFIER=12C-OLD` in the column
`AUTHENTICATION_TYPE` (2024-03-25) → [[gradual-password-rollover]].

## Impact on the wiki

New: [[audit-trail]], [[unified-audit-trail-operations]],
[[gradual-password-rollover]].

Cross-references added in [[short-lived-sessions]] (the audit trail as the first
search method), [[logon-trigger]] (the 2021 trick depends on it) and [[ash]].

## Notes on the evidence

**A solution superseded by a better one.** The post of 2021-01-05 carries its own
addendum "Update 2025-02". The LOGON trigger is therefore not wrong, but
superseded for unified auditing. Both routes are in [[audit-trail]], the older
one marked as such.

**A diagnosis with a clean chain of evidence.** For the slowness problem
(2025-01-17) the path leads from the execution plan via the wait event
`Disk file operations I/O` on the plan line to the conclusion that an `X$` table
here is **not** a wrapper around memory structures but points at files —
confirmed by a note in the documentation. Exemplary in its traceability.

**An explicitly named imprecision.** The housekeeping script calculates with the
*net* data size (`Avg_Row_Len` × row count). The author himself points out at the
end that the space actually allocated is higher — because of `PCTFREE`, LOB
indexes and the possibly nearly empty oldest partition.

## Source files

`raw/posts/46-*`, `53-*`, `58-*`, `63-*`, `65-*`
