---
title: OLTP compression only for tables without meaningful updates
type: decision
decision_status: superseded
status: draft
tags: [storage, compression, oracle]
created: 2026-10-01
updated: 2026-10-04
sources: [blog.md, posts/, speakerdeck.md, speakerdeck/]
---

# OLTP compression only for tables without meaningful updates

**Status: superseded** on 2026-10-04 by [[monitor-migrated-rows-under-advanced-compression]].
The rule *was*: `COMPRESS FOR OLTP` only for tables on which practically no
updates take place, with updates below 5 % of inserts plus deletes as a guide
value. It is kept as the record of the earlier position and still describes the
safe behaviour for releases 12.x and 18.x.

## The choice

Oracle describes OLTP compression as transparent for OLTP workloads. This
decision does **not** follow that assurance but restricts its use to tables with
insert and delete load but no update load.

## The rationale

The measurements in [[oltp-compression]] ([[blog-storage]], 2018-09-19):

- Insert and delete leave compressed blocks compressed, without migrated rows.
- An update on a **compressed** column produced migrated rows for **79.5 %** of
  the rows; if the new value was already in the block's symbol table, even for
  **95.7 %**. The block count rose by a factor of 19 in the process.
- An update on a **non**-compressed column was harmless.

> The price is therefore not only lost compression but migrated rows on top of it
> — that is, permanently more expensive single-row access. The measure turns into
> its opposite.

Hence the filter on `DBA_TAB_MODIFICATIONS` when searching for candidates: it is
not the size that decides suitability but the ratio of updates to the remaining
DML.

## Open at the time the decision stood

- **The rationale is partly superseded.** The author's addendum "Update 2023-05"
  finds that for **release 19.18** it works *"much better"* — but *"not
  completely without the risk of getting migrated rows and not deterministic at
  all"*. For 19.18 and newer the decision is therefore **more cautious than
  necessary**, but not refuted. No measurements exist for 19.18.
- **A newer statement by the author is milder than this decision.** In the talk
  of 2024-02 ([[talks-advanced-compression]]) the conclusion is no longer
  "unsuitable for tables with updates" but: on tables with a significant amount
  of updates, *keep the size and relevance of migrated rows in view*. For 19c
  and later that reads as **use it, and monitor** — not as "do not use it".
  **Resolved 2026-10-04:** the author decided to supersede this decision by
  [[monitor-migrated-rows-under-advanced-compression]].
- **"Not deterministic" remains unresolved.** As long as it is unclear what the
  migration behaviour depends on, the individual case cannot be assessed in
  advance — which is the actual argument for the conservative rule.
- **The 5 % threshold is a guide value**, not a measured tipping point. It comes
  from the source's candidate query, not from an experiment.
- **Not verified for 19.19 and newer**, 21c and 23ai.

## Provenance

- A reasoned position of the blog author in the post of **2018-09-19**
  ("OLTP-Compression – what's true and what's wrong"), supported by four
  reproducible tests, and explicitly directed against a statement in Oracle's own
  "Master Note for OLTP Compression".
- Partly revised by the author himself in the **addendum of 2023-05**.
- Ingested into the wiki on 2026-10-01.
- Relativised by the author's talk of **2024-02** (ingested 2026-10-04).
- **Superseded on 2026-10-04** by a statement of the author in the ingest session
  (a user statement, not a source in `raw/`) → [[monitor-migrated-rows-under-advanced-compression]].

## Relationships

- Successor: [[monitor-migrated-rows-under-advanced-compression]]
- Measurements and addendum: [[oltp-compression]]
- The other compression topic, with a different assessment:
  [[index-compression]]
- All methods compared: [[advanced-compression]]

## Sources

- [[blog-storage]]
- [[talks-advanced-compression]]
