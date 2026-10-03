---
title: cursor_sharing = FORCE is no substitute for prepared statements
type: decision
decision_status: adopted
status: draft
tags: [parsing, shared-pool, oracle]
created: 2026-10-01
updated: 2026-10-02
sources: [blog.md, posts/]
---

# cursor_sharing = FORCE is no substitute for prepared statements

**Status: adopted.** Missing bind variables are fixed in the application.
`cursor_sharing = FORCE` is not accepted as a solution, at best as a stopgap — it
removes part of the damage and conceals the rest.

## The obvious shortcut

For existing systems there appears to be a simpler solution than changing the
implementation: setting the parameter `cursor_sharing` from its default `EXACT`
to `FORCE`. The database then replaces literals with system-generated bind
variables itself.

## Why it is rejected

> "But this easy solution could be a false friend. While fixing some drawbacks
> like hard parses there are others remaining."
> — [[blog-bind-variables]], 2024-12-06

The load-bearing objection: **the original SQL texts nevertheless remain in the
SGA for a while** before the translation into system-generated bind variables
takes effect. The memory pressure from the large number of different SQL
therefore persists at least in part — which is precisely the damage that,
according to [[bind-variables-and-cursor-sharing]], affects the *entire* database
via the eviction of the buffer cache.

The post of 2017-09-11 quantifies the same observation more concretely: the full
SQL text before the translation is held in the **KHLH0 area** of the shared pool
and can take up gigabytes there as well.

> Conclusion: `FORCE` fixes the hard parses, not the memory consumption. Whoever
> sets it has moved the problem, not solved it.

## Open despite the decision (implementation risks)

- **"At least in part" is imprecise.** How large the remaining memory pressure
  actually is, the source does not quantify — only that it remains.
- **The stopgap sometimes remains the only way.** If the application cannot be
  changed, `FORCE` may still be better than nothing. The source does not reject
  it absolutely but warns against the mistaken belief that the problem is thereby
  fixed. The gentler alternative for individual SQL is
  [[sql-translation-framework]].
- **The trade-off with histograms remains.** Literals can help the optimizer;
  `FORCE` takes that information away from it. The source names the conflict in
  [[bind-variables-and-cursor-sharing]] but does not resolve it.

## Provenance

- A reasoned position of the blog author in the post of **2024-12-06** ("Detect
  missing use of prepared statements in SQLs"), supported by the observation
  about the KHLH0 area from the post of **2017-09-11**. Both in
  [[blog-bind-variables]].
- Ingested into the wiki on 2026-10-01.

## Relationships

- Mechanics and damage pattern: [[bind-variables-and-cursor-sharing]]
- Gentler alternative for individual cases: [[sql-translation-framework]]

## Sources

- [[blog-bind-variables]]
