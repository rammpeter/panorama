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

Four posts from [rammpeter.blogspot.com](../usage/rammpeter-blog.md) between 2013 and 2023 on how to find blocking
locks — currently and retrospectively — and how to create serialisation yourself
when there is no other way.

## The posts

| Date | Title | Focus |
|---|---|---|
| 2013-09-17 | Analyze affected objects for wait event "library cache: mutex X" | [Library cache contention](../usage/library-cache-contention.md) |
| 2016-06-03 | How to analyze blocking locks in Oracle-DB | [Blocking locks](../usage/blocking-locks.md) |
| 2020-10-06 | Retrospective analysis of blocking locks with Panorama | [Blocking locks](../usage/blocking-locks.md) |
| 2023-08-15 | Ensure uniqueness across table boundaries | [Cross-table uniqueness](../usage/cross-table-uniqueness.md) |

The post of 2020-10-06 explicitly builds on the one of 2016-06-03 and adds the
analysis via wait event pairs.

## Key points

**The root matters, not the leaf.** In a lock hierarchy you have to find the
session that is itself blocked by no other — only resolving that one frees the
whole chain. [Panorama](../usage/panorama.md) marks it orange and sorts the historical evaluation by
the cumulative wait time of all sessions it blocks (2016-06-03)
→ [Blocking locks](../usage/blocking-locks.md).

**You can get down to the individual row.** File, block and row number yield the
ROWID, and the ROWID yields the primary key of the blocking row — that is, the
concrete record it hangs on (2016-06-03).

**Retrospective lock analysis goes through ASH.** That requires Enterprise
Edition and the Diagnostics Pack — or the [Panorama Sampler](../usage/panorama-sampler.md), which Panorama
evaluates *transparently in the same way* (2020-10-06)
→ [Management pack licensing](../usage/management-pack-licensing.md).

**Three directions of analysis** (2020-10-06): top-down via the dependency tree
to the root session; top-down via **wait event pairs** (blocking versus blocked
event), which stays manageable even with very many sessions involved; and
bottom-up from a single blocked session.

**`DETERMINISTIC` is an assertion, not a check.** A function whose return value
depends on table contents is not deterministic — even if you write the keyword.
A function based index on top of it leads to `ORA-08102: index key not found`
after the table read has changed (2023-08-15)
→ [Cross-table uniqueness](../usage/cross-table-uniqueness.md), [DETERMINISTIC](../usage/deterministic.md).

**Home-made uniqueness costs serialisation.** For uniqueness across table
boundaries only triggers remain — and they only work correctly if competing
transactions are serialised, in the example via
`LOCK TABLE … IN EXCLUSIVE MODE` (2023-08-15).

## Impact on the wiki

New: [Blocking locks](../usage/blocking-locks.md), [Library cache contention](../usage/library-cache-contention.md),
[Cross-table uniqueness](../usage/cross-table-uniqueness.md).

Extended: [Panorama Sampler](../usage/panorama-sampler.md) — this block supplies the clearest statement so
far about its role. Cross-references in [Foreign keys and locks](../usage/foreign-key-locks.md) (DML locks as a
cause) and [ASH](../usage/ash.md).

## Notes on the evidence

**An explicitly incomplete result.** On the uniqueness problem the author writes:
*"Unfortunately, I have not yet found a waterproof solution with that trigger
approach without global serialization, at least for insert DML."* The solution is
therefore deliberately marked as a compromise, not as a recommendation —
recorded as such in [Cross-table uniqueness](../usage/cross-table-uniqueness.md).

**The optimisation is documented in stages.** The post of 2023-08-15 develops the
check query over four stages (brute force → restriction via index →
pre-grouping → index-only access) and shows the plan for each. The intermediate
stages are summarised in the wiki as a path, not filed individually.

**Screenshots carry a lot here.** Both lock posts explain Panorama's interface
largely through images that the feed does not supply. The descriptions in the
wiki rest on the accompanying text.

## Source files

`raw/posts/05-*`, `13-*`, `44-*`, `52-*`
