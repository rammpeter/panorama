---
title: Long operations
type: concept
status: draft
tags: [system-load, partitioning, oracle]
created: 2026-10-01
updated: 2026-10-02
sources: [blog.md, posts/]
---

# Long operations

`GV$SESSION_LONGOPS` shows long-running operations with their progress and
estimated remaining time. What it does not show: **which partition** is currently
being read.

## The addition

([[blog-system-load]], 2026-09-16) The route goes via
`GV$SESSION.ROW_WAIT_OBJ#` — the object ID of the object the session is currently
accessing. Via `DBA_OBJECTS` that becomes the owner, object name, **sub-object
name** (that is, the partition) and object type.

`GV$SESSION_LONGOPS` is joined with `GV$SESSION` via instance, SID, `Serial#`,
`SQL_ID` and `SQL_EXEC_ID` — the last two so that the session is not meanwhile
doing something else.

Additionally the query computes an **end time** from
`Last_Update_Time + Time_Remaining`, with one exception: for
`OpName = 'Sort Output'` it stays empty, because the remaining-time estimate does
not hold there.

## The built-in counter-check

The most instructive part is the column **`Object_Belongs_To_Target_Table`**. It
checks whether the information obtained via `ROW_WAIT_OBJ#` fits the target object
of the long operation at all:

- Does the object belong directly to the target table (`Target_Owner` /
  `Target_Table_Name` split out of the `Target` column)? → `YES`
- Is it an **index** of that table? → `YES`
- Otherwise → `NO`, the information is not usable.

> The reason for this: `ROW_WAIT_OBJ#` says what the session is waiting on *right
> now* — which need not be the object of the long-running operation. The method
> is heuristic, and the source makes that uncertainty visible in the result
> itself instead of concealing it.

## In Panorama

Two views using the same logic: all long operations under "SGA/PGA-details /
SQL-Area / Long operations", and per session under consideration. The author
credits Matthias Rogel for the inspiration.

## Relationships

- The live complement to [[measuring-system-load]]: not what was, but what is
  running right now.
- Partition reference: [[partitioning]].
- Unlike [[ash]], without a licensing caveat — `GV$SESSION_LONGOPS` and
  `GV$SESSION` are base views.

## Open questions

- How often does the heuristic miss, that is, how frequently does `NO` appear in
  the check column?
- Can the partition also be determined retrospectively? `ROW_WAIT_OBJ#` is live
  information; ASH holds `CURRENT_OBJ#` — whether that is equivalent the source
  does not address.

## Sources

- [[blog-system-load]]
