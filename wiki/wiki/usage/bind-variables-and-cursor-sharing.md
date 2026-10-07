---
title: Bind variables and cursor sharing
type: concept
status: draft
tags: [core, parsing, shared-pool, oracle]
created: 2026-10-01
updated: 2026-10-04
sources: [blog.md, posts/, speakerdeck.md, speakerdeck/]
---

# Bind variables and cursor sharing

If an application writes values into the SQL text as literals instead of binding
them, **every value produces its own SQL** with its own SQL ID, its own hard
parse and its own entry in the SQL area. One of the most long-lived problems
there is — the author pursues it across seven years in two posts.

## What it costs

Seven consequences ([Blog series on bind variables and SQL text](../sources/blog-bind-variables.md), 2024-12-06):

- **SQL injection** — foreign content in the executed SQL code is a classic
  security hole as soon as the value comes from outside.
- **Execution time** — every new value yields a new syntax; no existing plan can
  be reused. The hard parse often takes considerably longer than the execution
  itself.
- **CPU** — hard parses consume significant CPU time on the database machine.
- **Memory** — the parsed SQL sits in the cursor cache together with its plan and
  permanently displaces other, reusable SQL.
- **Buffer cache efficiency** — if the SQL area grows unbounded, the automatic
  SGA management shrinks the buffer cache. The hit rate drops, and it does so
  **for the entire database**, not just for the guilty SQL.
- **Monitoring data** — the AWR recordings grow accordingly as well.
- Plus the risk of queuing at mutexes and latches in the library cache.

## The quantity decides

Remarkably nuanced ([Blog series on bind variables and SQL text](../sources/blog-bind-variables.md), 2024-12-06): the severity depends on
the **variety of the literals**, not on the principle.

- If the value does not come from outside and a few dozen or a few hundred
  variants result, that can be tolerable.
- It can even be **useful**: explicit values instead of bind variables help the
  optimizer choose different, individually optimal plans via histograms.
- With thousands or millions of different values the drawbacks clearly outweigh
  that.

> Recommendation from the source, explicitly "for most cases": prepared
> statements with value binding instead of literals in the SQL text. On the
> obvious shortcut see [cursor_sharing = FORCE is no substitute for prepared statements](cursor-sharing-force-is-no-substitute.md).

## Three search methods

In the ranking of 2024-12-06, which supersedes the 2017-09-11 version:

**1. Same force-matching signature, different SQL ID.** The hash value of the
*theoretical* result of a conversion into system-generated bind variables —
available even without `cursor_sharing = FORCE`. The most accurate method.

**2. Same plan hash value, different SQL ID.** Many different SQL IDs with an
identical plan point to missing binding. Less accurate than the signature, but it
also catches SQL whose force-matching signature is 0 — inserts, for instance.
False positives are possible but rarely have such large counts.

**3. Same leading characters.** A comparison of the first *n* characters, on the
assumption that the differences sit behind the WHERE clause at the end. The
author calls the method "stupid" himself, but it also catches cases without a
signature **and** without a plan hash value — PL/SQL calls, for instance.

All three are available as ready-made queries against the current SGA
(`GV$SQLAREA`) and against the AWR history; in [Dragnet Investigation](dragnet.md) as points 4.1 to 4.3
(2017) and 4.1.1 to 4.1.5 (2024) respectively.

## Quantifying the damage

A practical measure from [Blog series on bind variables and SQL text](../sources/blog-bind-variables.md) (2017-09-11): the ratio of SQL
area to buffer cache.

- Usual sizes for the shared pool on larger systems are between 0.5 and 2 GB;
  the larger part of the SGA should be available to the buffer cache.
- If the SQL area is **considerably larger than the buffer cache**, that is often
  a signal of a massive problem with missing bind variables.

To be inspected in [Panorama](panorama.md) under "SGA/PGA-Details" / "SGA components" →
[SGA memory management](sga-memory-management.md).

## Cursor sharing and child cursors

Several child cursors for one SQL can lead to different execution plans.
[Panorama](panorama.md) shows the reasons for their existence on the SQL detail page from
the SGA via the button "Cursor sharing (n versions)"
([Blog series on execution plans and the optimizer](../sources/blog-execution-plans.md), 2016-04-27) → [Execution plans](execution-plans.md).

## Relationships

- The shortcut that is not one: [cursor_sharing = FORCE is no substitute for prepared statements](cursor-sharing-force-is-no-substitute.md).
- If the SQL text cannot be changed in the application,
  [SQL Translation Framework](sql-translation-framework.md) helps.
- Affects [Execution plans](execution-plans.md) via child cursors.
- Drives the skew described in [SGA memory management](sga-memory-management.md).
- The search via ASH and AWR requires [Management pack licensing](management-pack-licensing.md).
- The client-side counterpart for *soft* parses, the JDBC statement cache:
  [Proactive performance tuning](proactive-performance-tuning.md).

## Open questions

- The talk of 2026-05 ([Talks on dragnet investigation and proactive tuning](../sources/talks-dragnet-and-proactive-tuning.md), slide 22) says
  "`cursor_sharing=EXACT` can reduce the problem, but with other side effects".
  `EXACT` is the default; everything else in the sources, including
  [cursor_sharing = FORCE is no substitute for prepared statements](cursor-sharing-force-is-no-substitute.md), speaks of `FORCE`.
  **Confirmed by the author on 2026-10-04: a slip, `FORCE` is meant.** The slide
  in `raw/speakerdeck/2026-05_DOAG_Datenbank_Firefighting_or_Fixing_Root_Causes.pdf`
  still carries the wrong word; the published deck would need correcting.
- At what number of variants does the assessment actually tip? The source says a
  few dozen or hundred is tolerable, thousands or millions is not — the grey area
  in between remains open.
- How do you weigh the histogram advantage against the parse cost? The source
  names the trade-off but does not resolve it.
- The post of 2024-12-06 ends with an open question to readers: *"Are there other
  ideas how to identify and catch these issues?"*

## Sources

- [Blog series on bind variables and SQL text](../sources/blog-bind-variables.md)
- [Blog series on execution plans and the optimizer](../sources/blog-execution-plans.md)
- [Talks on dragnet investigation and proactive tuning](../sources/talks-dragnet-and-proactive-tuning.md)
