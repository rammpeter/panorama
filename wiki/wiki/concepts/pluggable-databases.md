---
title: Pluggable databases
type: concept
status: draft
tags: [oracle, multitenant]
created: 2026-10-01
updated: 2026-10-02
sources: [blog.md, posts/]
---

# Pluggable databases

In a multitenant environment, what you see at all depends on **where you are
connected** and **which family of views** you query. For every analysis that is
the prior question.

## The visibility matrix

([[blog-panorama-the-tool]], 2016-12-09)

| Connected as | `CDB_xx` in the CDB (root) | `DBA_xx` in the CDB (root) | `CDB_xx` in the PDB | `DBA_xx` in the PDB |
|---|---|---|---|---|
| **system** | all PDBs incl. root | all PDBs incl. root | nothing | the current PDB |
| **user** with `SELECT ANY DICTIONARY` | all PDBs incl. root | **the root CDB only** | nothing | the current PDB |

**The two remarkable cells:**

> `CDB_xx` **inside a PDB** returns **nothing** — not the PDB's own data but
> nothing at all. So a query that works correctly in the root silently returns an
> empty result in the PDB.
>
> `DBA_xx` **in the root as an ordinary user** returns only the root CDB, while
> the same access as `system` shows all PDBs. The same SQL, the same place, a
> different result depending on the user.

The practical consequence: an empty analysis result in a multitenant environment
should first be suspected of being a connection or view problem, not a finding.

## Relationships

- Affects every evaluation via `DBA_*` views, so practically every concept in
  this wiki — [[indexing]] and [[storage-reorganisation]], for instance.
- A related topic in AWR queries: the DBID filter, so that values are not counted
  multiple times — see [[partition-pruning]] and [[parallel-execution]], where
  the queries carry `WHERE DBID = :DBID` "to not count multiple times for
  multiple different DBIDs/ConIDs".
- [[panorama]] has supported the analysis of PDBs since 2016.

## Open questions

- Does the matrix apply unchanged for all releases from 12.1? The post is from
  2016 and names no version.
- How does it behave with `V$` and `GV$` views and with `CON_ID`? The post only
  covers `CDB_xx` and `DBA_xx`.
- What privileges does a Panorama user need in order to evaluate all PDBs?

## Sources

- [[blog-panorama-the-tool]]
