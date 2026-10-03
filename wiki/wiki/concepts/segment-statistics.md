---
title: Segment statistics
type: concept
status: draft
tags: [system-load, storage, oracle]
created: 2026-10-01
updated: 2026-10-02
sources: [blog.md, posts/]
---

# Segment statistics

`GV$SEGSTAT` and `GV$SEGMENT_STATISTICS` carry cumulative metrics per segment —
which table, which index was read, written or locked how often. They end up in
[[awr]] via `DBA_HIST_SEG_STAT`.

## The problem

([[blog-system-load]], 2024-09-29) Sometimes you do not want to wait for the next
AWR snapshot — or its resolution is too coarse. The live view does not help
directly, though:

> `GV$SEGMENT_STATISTICS` contains only values accumulated since the last restart
> of the database — or since other events, possibly since the last loading of
> blocks of a segment into the buffer cache.

A total since an indeterminate point in time says nothing about the last few
minutes.

## The solution: sample twice

The method takes the difference: read once, wait *x* seconds, read again, output
the differences. Reported are all segments and statistics whose value changed in
the period under consideration.

**What is remarkable is the packaging:**

> "The entire function is encapsulated within a single SELECT SQL, so that
> nothing needs to be installed or changed at the target DB."

Via `WITH FUNCTION` — a PL/SQL function inside the SQL statement — the whole
logic sits in *one* SELECT. Nothing has to be created on the target database: no
package, no table, no job. For a production database on which you are not allowed
to install anything, that is the decisive point.

The structure in detail:

1. Two associative arrays, indexed by a composite key of instance, owner, object,
   sub-object, object type and statistic name.
2. First snapshot, time measurement, `DBMS_SESSION.SLEEP` over the remaining
   time, second snapshot.
3. Difference calculation, returned as `SYS.DBMS_DEBUG_VC2COLL` — a string
   collection in which the key parts are separated by `^`.
4. The surrounding SELECT splits the strings back into columns via
   `INSTR`/`SUBSTR` and groups across the instances.

**A built-in plausibility check:** if the snapshot from
`GV$SEGMENT_STATISTICS` itself takes longer than the desired interval between the
samples, the function aborts with an intelligible error message and demands a
larger interval. Without that check the differences would be silently wrong.

## Relationships

- Finer and available faster than [[awr]] snapshots, the same line of enquiry as
  [[measuring-system-load]].
- Returning a collection from a single SELECT is the same motive as in
  [[sampling-session-statistics]]: compute the differences yourself, because
  Oracle only offers totals — but here without any installation.
- Available more conveniently in [[panorama]].

## Open questions

- What overhead does a full snapshot from `GV$SEGMENT_STATISTICS` cause on a
  system with very many segments?
- Which of the numerous statistics per segment are the most informative in
  practice? The source supplies all of them without assessing them.
- What exactly are the "other events" that reset the counter? The source
  suspects the loading of blocks into the buffer cache but remains unsure.

## Sources

- [[blog-system-load]]
