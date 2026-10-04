---
title: Index usage monitoring
type: concept
status: draft
tags: [index, oracle]
created: 2026-10-01
updated: 2026-10-02
sources: [blog.md, posts/]
---

# Index usage monitoring

The measurement technique for proving role 1 from [[indexing]]: is an index still
used by user SQL at all? Both available methods have blind spots you must know
before deriving a "this one can go" from their result.

## Method 1: MONITORING USAGE

Activated via `ALTER INDEX <Index_Name> MONITORING USAGE`. Oracle then maintains
a yes/no flag that flips to `YES` as soon as a SQL uses the index. Together with
the start timestamp of the monitoring this reveals which indexes have not been
used since when. Readable via `V$OBJECT_USAGE` (own schema only) or
`sys.OBJECT_USAGE` (the whole database, less convenient).

What to watch out for ([[blog-indexing]], 2017-10-12 and 2019-12-27):

- **Only direct SQL is recorded.** The database's own recursive access does not
  count — in particular **not** the implicit use of an index when checking a
  foreign key constraint. Role 3 from [[indexing]] must therefore always be ruled
  out separately, see [[foreign-key-locks]].
- **Only a state, not a timestamp.** What is logged is the start time and the
  state, not when the index was last used.
- **Resetting is mandatory.** Without regular resets you only identify indexes
  never used, not those used at some point in the past. Executing
  `ALTER INDEX … MONITORING USAGE` again resets the start time and the state.
- **The reset is DDL** and invalidates all cursors using that index. For
  frequently executed statements with many sessions the resulting hard parse can
  itself become a performance problem.

The blog solves the last point elegantly: the reset is performed only for indexes
that appear in **no** current execution plan in the SGA (`GV$SQL_PLAN`). If the
index does appear there, that is already sufficient proof of usage — resetting
becomes unnecessary and the reparse storm is avoided. Plans with
`Options = 'SAMPLE FAST FULL SCAN'` are excluded, because those would be accesses
from `DBMS_STATS`.

## Method 2: DBA_INDEX_USAGE (from 12.2)

Considerably richer: the view does not need to be activated, logs by default, and
contains the time of last use as well as volume distributions of accesses and
result sets.

Its limits ([[blog-indexing]], 2019-12-27):

- The data is **sampled**; a latent risk remains that an actual use is not
  logged. Switching to gap-free logging
  (`ALTER SESSION SET "_iut_stat_collection_type"=ALL` instead of `SAMPLED`)
  brings a significant performance penalty.
- The in-memory data is only flushed to disk every 15 minutes and becomes visible
  afterwards.
- As with method 1, only direct SQL counts, not recursive.
- An analysis of the index (such as `DBMS_STATS.GATHER_INDEX_STATS`) also counts
  as usage.

> Conclusion from the source: `DBA_INDEX_USAGE` therefore does **not** allow
> usage to be safely ruled out. For the detailed investigation of *how* an index
> is used, however, it is helpful.

## The counter-check: references in hints and SPM

Before dropping an index identified as unused, one last search for its name is
worthwhile ([[blog-indexing]], 2026-07-02): are there optimizer hints in SQL
statements, SQL patches, SQL profiles or SQL plan baselines pointing at it?

`sys.sqlobj$data` supplies the hits (for profiles, patches, baselines) and the
`hint_usage` section in `GV$SQL_PLAN.OTHER_XML` (for directly placed hints).

Limitation from the source: in baselines you will usually *not* find the index
name, because they mostly address the index via its column names. The author
himself classifies the check as a question of clean structures — if the index
were really in use via a baseline, it would hardly be marked as unused over a
longer period.

## The DML load of the referenced table

To assess role 3 you additionally need to know how much DML takes place on the
referenced table at all. `DBA_TAB_MODIFICATIONS` serves that purpose, with the
counts for insert, update and delete since the last analysis.

**Documentation diverges from observation** ([[blog-indexing]], 2019-12-27): up
to 19c the Oracle documentation requires the status `MONITORING=YES` at table
level for logging in `DBA_TAB_MODIFICATIONS`. In reality, however, DML operations
are recorded from release 11 onwards even with `NOMONITORING`.

## Relationships

- Supplies the proof for role 1 from [[indexing]].
- Explicitly does **not** cover role 3 → [[foreign-key-locks]].
- [[panorama]] presents the usage state in the table and index structure and
  brings it together with the other three roles in one list in [[dragnet]].

## Open questions

- Can the gap for recursive access be closed in some way other than by checking
  the foreign key roles separately?
- After what period without usage does an index count as dispensable in practice?
  The blog names 8 days as the reset interval but no threshold for the decision
  itself.

## Sources

- [[blog-indexing]]
