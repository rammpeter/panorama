---
title: Dragnet Investigation
type: entity
subtype: component
status: draft
tags: [panorama]
created: 2026-10-01
updated: 2026-10-02
sources: [blog.md, posts/]
---

# Dragnet Investigation

Panorama's catalogue of ready-made search queries: system-wide scans that comb an
entire database system for a known problem pattern instead of investigating a
single case. Found under the menu "Spec. additions" / "Dragnet investigation".

## Summary

What distinguishes it from the rest of [[panorama]] is the direction of the
question: the normal views answer "what is wrong with *this* SQL / *this*
session?", dragnet answers "where in my system does *this pattern* occur?". Hits
are sorted by relevance, and from there links lead into the detail views.

The entries are numbered and are cited in the blog posts by their number (e.g.
"point 1.2" for superfluous indexes, "point 2.6" for changing execution plans) —
the numbering appears to have been stable over the years.

## Extensibility

([[rammpeter-blog]], 2016-03-20)

- Via "Add personal selection" in the "≡" menu, **your own SQL** can be added. It
  resides on the Panorama server instance and is visible only to your own browser
  instance; it appears under a separate menu entry "Personal extensions".
- To make it permanent and available to all users of a Panorama instance, it is
  stored as a JSON array in a file `predefined_dragnet_selections.json` in the
  directory `PANORAMA_VAR_HOME`.

## Known entries from the blog

- List superfluous indexes (point 1.2) → [[indexing]]
- Unused indexes across all schemas → [[index-usage-monitoring]]
- Recommendation lists for index compression → [[index-compression]]
- Index access with skipped columns → [[index-access-paths]]
- Statements with changing execution plans (point 2.6) → [[execution-plans]]
- SQL with literals instead of bind variables (points 4.1 to 4.3, later 4.1.1 to
  4.1.5) → [[bind-variables-and-cursor-sharing]]
- Extremely short-running SQL in parallel query mode → [[ash]]
- Inappropriate sequence caches (points 3.8 and 3.9) → [[sequence-caching]]
- SQL where parallel DML or direct load does not work (point 2.2.12) and
  candidates for the shared hash join (point 2.2.11) → [[parallel-execution]]
- Estimating network latency → [[network-latency-from-ash]]
- SQL missing partition pruning → [[partition-pruning]]
- Functions without a `DETERMINISTIC` flag → [[deterministic]]

## Relationships

- A component of [[panorama]].
- Many entries require [[awr]] or [[ash]] and therefore a licence per
  [[management-pack-licensing]].

## Open questions

- How many entries does the catalogue contain in total, and how is it structured?
  The blog only cites individual numbers.
- Can custom entries also be maintained under version control or in the
  repository, rather than only via `PANORAMA_VAR_HOME`?

## Sources

- [[blog-indexing]]
- [[blog-panorama-the-tool]]
- [[rammpeter-blog]]
