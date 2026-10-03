---
title: Blog series on bind variables and SQL text
type: source
status: maintained
tags: [parsing, shared-pool, oracle]
created: 2026-10-01
updated: 2026-10-02
sources: [blog.md, posts/]
---

# Blog series on bind variables and SQL text

Three posts from [[rammpeter-blog]] on a problem that, by the author's own
account, "has been haunting me for years": SQL that writes values into the text
as literals instead of binding them — and what can be done about it without
changing the application.

## The posts

| Date | Title | Focus |
|---|---|---|
| 2017-09-11 | Scan Oracle-DB for excessive execution of SQL with literals instead of bind variables | [[bind-variables-and-cursor-sharing]] |
| 2017-09-13 | Use "SQL Translation Framework" to quickly fix problems with SQLs | [[sql-translation-framework]] |
| 2024-12-06 | Detect missing use of prepared statements in SQLs | [[bind-variables-and-cursor-sharing]], [[cursor-sharing-force-is-no-substitute]] |

The post of 2024-12-06 is explicitly framed as the sum of what has been learned
since 2017: *"This problem pattern has been haunting me for years, there was a
post about that in this blog also from 2017. It is now time to sum up the ideas
that have emerged in the meantime."*

## Key points

**The damage is broader than "slower parsing".** The post of 2024-12-06 lists
seven consequences, from SQL injection through CPU consumption caused by hard
parses to the eviction of the buffer cache and the bloating of AWR recordings
→ [[bind-variables-and-cursor-sharing]].

**The quantity decides, not the principle.** A few dozen or a few hundred
variants can be tolerable — and literals can even help the optimizer to better
plans via histograms. With thousands or millions of different values the
drawbacks clearly outweigh that (2024-12-06).

**`cursor_sharing = FORCE` is a false friend.** It fixes the hard parses, but the
original SQL texts remain in the SGA before the translation happens — the memory
pressure partly persists
→ [[cursor-sharing-force-is-no-substitute]].

**Three search methods, with a clear ranking.** Force-matching signature (the
most accurate), the same plan hash value with different SQL IDs (also catches
cases without a signature, such as inserts) and the same leading characters
(crude, but also catches PL/SQL calls)
→ [[bind-variables-and-cursor-sharing]].

**The SQL text can be replaced entirely.** The SQL Translation Framework from
12.1 swaps the whole text before processing — not just hints as a SQL patch does.
That makes it possible to fix any problem solvable via the SQL text without
touching the application (2017-09-13)
→ [[sql-translation-framework]].

## An evolution, not a contradiction

The post of 2017-09-11 names three search methods: same plan in ASH, same plan in
the SGA, same leading characters. The one of 2024-12-06 puts the
**force-matching signature** ahead of these and rates it as the most accurate
method. The older methods are not discarded but placed in context — they cover
cases where no signature exists.

What is recorded is the 2024-12-06 version; the 2017 one is considered superseded
as far as the ranking is concerned.

## Impact on the wiki

New: [[bind-variables-and-cursor-sharing]], [[sql-translation-framework]] and the
decision [[cursor-sharing-force-is-no-substitute]].

Cross-references added in [[execution-plans]] (child cursors as a cause of
multiple plans) and [[sql-plan-management]] (SQL patch vs. translation).

## Side finding

The post of 2024-12-06 points to another location of the author's outside the
blog: <https://rammpeter.github.io/oracle_performance_tuning.html> with
ready-made selections (points 4.1.1 to 4.1.5 there), which are also part of
[[dragnet]]. Not yet ingested.

## Source files

`raw/posts/25-*`, `26-*`, `62-*`
