---
title: Use advanced compression with updates, and monitor migrated rows
type: decision
decision_status: adopted
status: draft
tags: [storage, compression, oracle]
created: 2026-10-04
updated: 2026-10-04
sources: [speakerdeck.md, speakerdeck/2024-02-IT-Tage_Advanced-Compression.pdf, blog.md, posts/]
---

# Use advanced compression with updates, and monitor migrated rows

**Status: adopted.** `COMPRESS ADVANCED` (formerly `COMPRESS FOR OLTP`) may be
used on tables that receive updates. The condition is not the absence of updates
but that the size and relevance of **migrated rows** on such tables is watched.
Supersedes [[oltp-compression-only-without-updates]].

## The choice

- Advanced compression is no longer withheld from a table because it is updated.
- For a compressed table with a significant amount of update DML, migrated rows
  are monitored; if they grow to a relevant extent, the table is reorganised or
  the compression reconsidered for that table.
- The rule applies to release 19 and later. For 12.x and 18.x the superseded
  rule still describes the safe behaviour.

## The rationale

Stated by the author in the talk of 2024-02
([[talks-advanced-compression]], slide 17):

- In 12.x and 18.x, updates on compressed tables moved rows that no longer
  fitted their block into overflow blocks, where they stayed migrated; in the
  extreme, the table grew beyond its uncompressed size.
- With release 19 (tested with 19.18) this "still occurs sporadically, but with
  drastically lower risk".
- Conclusion of the talk: with `COMPRESS ADVANCED` on tables with a significant
  amount of update DML, "the size and relevance of migrated rows should be kept
  in view".

The blog's own addendum of 2023-05 had already found 19.18 to work "much
better", though "not deterministic at all" ([[oltp-compression]]).

> Conclusion: the earlier rule excluded a whole class of tables from a feature
> that — on the same talk's numbers — costs nothing on single-row access and
> saves a factor of 2 to 4, sometimes far more ([[advanced-compression]]). With
> the failure now sporadic instead of systematic, watching for it is cheaper
> than forgoing the saving.

## How to monitor

The means are in the sources; the routine is not (see below).

- **Per row:** access by ROWID must cost exactly one consistent get; any excess
  indicates a migrated row. The post's function `Chained_Row_Test` counts this
  ([[oltp-compression]]).
- **Per table:** a compressed table whose size grows without a matching growth
  in rows — in the extreme beyond the uncompressed size — is the visible
  symptom. Size history is available from the [[panorama-sampler]]'s object
  size recording; expected size and actual compression per row in [[panorama]]
  ([[advanced-compression]]).
- **Where to look first:** compressed tables with a high share of updates in
  `DBA_TAB_MODIFICATIONS`.
- **Remedy:** reorganisation ([[storage-reorganisation]]).

## Open despite the decision (implementation risks)

- **No monitoring routine is defined.** Neither source says how often to check,
  nor at what share of migrated rows to act. "Keep in view" is the whole
  instruction.
- **"Not deterministic" is unexplained.** What decides whether an update
  migrates a row under 19c is unknown, so the risk for a given table cannot be
  assessed in advance — only observed.
- **No measurements for 19c.** Both the addendum and the talk give a qualitative
  assessment for 19.18. The four tests of 2018 were not published with 19c
  results.
- **Not verified beyond 19.18** — 19.19 and later, 21c, 23ai.
- **The Advanced Compression Option is required**; the rule says nothing about
  whether licensing it pays for a given system
  ([[management-pack-licensing]]).

## Provenance

- **Decided by the author of Panorama on 2026-10-04**, in the session in which
  the talks were ingested: asked whether the earlier decision should be narrowed
  to releases before 19 or superseded, he chose to supersede it by a "monitor
  migrated rows" rule. This rests on a **statement by the user**, not on a
  document in `raw/`.
- The substance rests on his talk of 2024-02 (IT-Tage, slide 17) and the blog
  addendum of 2023-05.
- The earlier position: post of 2018-09-19, recorded as
  [[oltp-compression-only-without-updates]].

## Relationships

- Supersedes: [[oltp-compression-only-without-updates]]
- Measurements and the three statements over time: [[oltp-compression]]
- All compression methods compared: [[advanced-compression]]
- The remedy: [[storage-reorganisation]]

## Sources

- [[talks-advanced-compression]]
- [[blog-storage]]
