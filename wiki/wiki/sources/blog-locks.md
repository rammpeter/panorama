---
title: Blog series on locks and serialisation
type: source
status: maintained
tags: [locks, oracle]
created: 2026-10-01
updated: 2026-10-02
sources: [blog.md, posts/]
---

# Blog series on locks and serialisation

Four posts from [[rammpeter-blog]] between 2013 and 2023 on how to find blocking
locks — currently and retrospectively — and how to create serialisation yourself
when there is no other way.

## The posts

| Date | Title | Focus |
|---|---|---|
| 2013-09-17 | Analyze affected objects for wait event "library cache: mutex X" | [[library-cache-contention]] |
| 2016-06-03 | How to analyze blocking locks in Oracle-DB | [[blocking-locks]] |
| 2020-10-06 | Retrospective analysis of blocking locks with Panorama | [[blocking-locks]] |
| 2023-08-15 | Ensure uniqueness across table boundaries | [[cross-table-uniqueness]] |

The post of 2020-10-06 explicitly builds on the one of 2016-06-03 and adds the
analysis via wait event pairs.

## Key points

**The root matters, not the leaf.** In a lock hierarchy you have to find the
session that is itself blocked by no other — only resolving that one frees the
whole chain. [[panorama]] marks it orange and sorts the historical evaluation by
the cumulative wait time of all sessions it blocks (2016-06-03)
→ [[blocking-locks]].

**You can get down to the individual row.** File, block and row number yield the
ROWID, and the ROWID yields the primary key of the blocking row — that is, the
concrete record it hangs on (2016-06-03).

**Retrospective lock analysis goes through ASH.** That requires Enterprise
Edition and the Diagnostics Pack — or the [[panorama-sampler]], which Panorama
evaluates *transparently in the same way* (2020-10-06)
→ [[management-pack-licensing]].

**Three directions of analysis** (2020-10-06): top-down via the dependency tree
to the root session; top-down via **wait event pairs** (blocking versus blocked
event), which stays manageable even with very many sessions involved; and
bottom-up from a single blocked session.

**`DETERMINISTIC` is an assertion, not a check.** A function whose return value
depends on table contents is not deterministic — even if you write the keyword.
A function based index on top of it leads to `ORA-08102: index key not found`
after the table read has changed (2023-08-15)
→ [[cross-table-uniqueness]], [[deterministic]].

**Home-made uniqueness costs serialisation.** For uniqueness across table
boundaries only triggers remain — and they only work correctly if competing
transactions are serialised, in the example via
`LOCK TABLE … IN EXCLUSIVE MODE` (2023-08-15).

## Impact on the wiki

New: [[blocking-locks]], [[library-cache-contention]],
[[cross-table-uniqueness]].

Extended: [[panorama-sampler]] — this block supplies the clearest statement so
far about its role. Cross-references in [[foreign-key-locks]] (DML locks as a
cause) and [[ash]].

## Notes on the evidence

**An explicitly incomplete result.** On the uniqueness problem the author writes:
*"Unfortunately, I have not yet found a waterproof solution with that trigger
approach without global serialization, at least for insert DML."* The solution is
therefore deliberately marked as a compromise, not as a recommendation —
recorded as such in [[cross-table-uniqueness]].

**The optimisation is documented in stages.** The post of 2023-08-15 develops the
check query over four stages (brute force → restriction via index →
pre-grouping → index-only access) and shows the plan for each. The intermediate
stages are summarised in the wiki as a path, not filed individually.

**Screenshots carry a lot here.** Both lock posts explain Panorama's interface
largely through images that the feed does not supply. The descriptions in the
wiki rest on the accompanying text.

## Source files

`raw/posts/05-*`, `13-*`, `44-*`, `52-*`
