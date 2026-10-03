---
title: OLTP compression only for tables without meaningful updates
type: decision
decision_status: adopted
status: draft
tags: [storage, compression, oracle]
created: 2026-10-01
updated: 2026-10-02
sources: [blog.md, posts/]
---

# OLTP compression only for tables without meaningful updates

**Status: adopted** — with an explicitly limited evidence base, see below.
`COMPRESS FOR OLTP` is used only for tables on which practically no updates take
place. As a guide value: updates below 5 % of inserts plus deletes.

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

## Open despite the decision (implementation risks)

- **The rationale is partly superseded.** The author's addendum "Update 2023-05"
  finds that for **release 19.18** it works *"much better"* — but *"not
  completely without the risk of getting migrated rows and not deterministic at
  all"*. For 19.18 and newer the decision is therefore **more cautious than
  necessary**, but not refuted. No measurements exist for 19.18.
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

## Relationships

- Measurements and addendum: [[oltp-compression]]
- The other compression topic, with a different assessment:
  [[index-compression]]

## Sources

- [[blog-storage]]
