---
title: Do not blanket-index foreign keys
type: decision
decision_status: adopted
status: draft
tags: [index, locks, oracle]
created: 2026-10-01
updated: 2026-10-02
sources: [blog.md, posts/]
---

# Do not blanket-index foreign keys

**Status: adopted.** The position is: the widespread dogma "every foreign key
column must be indexed" is rejected. An index on the referencing column is
created only where the DML load on the referenced table justifies it.

## The dogma

> "You always need to index all the column(s) for which you define a foreign key
> constraint!"

The author explicitly contradicts this in [[blog-indexing]] (2016-11-25):
*"I definitely do not agree with this dogma and want to explain why."*

## The rationale

**The price of the dogma is measurable.** There are real systems where more than
50 % of the storage requirement is taken up by indexes that serve only to protect
all referential constraints — without any other benefit. These indexes are
typically very unselective and therefore useless for data access, yet they cost
storage and maintenance effort on every DML.

**The risk is narrower than the dogma assumes.** The lock measurements in
[[foreign-key-locks]] across releases 11.2, 12.1 and 19.3 show:

- Inserts on the referenced table never block.
- Updates **without** the primary key column in the SET clause never block.
- Updates **with** the primary key column blocked only under 11.2; from 12.1
  onwards no longer.
- Only **deletes** on the referenced table block consistently across all tested
  releases.

**Two conditions make the index dispensable** ([[blog-indexing]], 2019-12-27):

- If there is practically no DML on the referenced table — the normal case for
  master data tables — no protection is needed.
- Even with little DML it often remains dispensable: a one-off full table scan
  every few weeks is usually cheaper than maintaining an index permanently.

## The accompanying convention

So that the second risk case disappears entirely, the decision comes with a rule
for handling primary keys:

**Primary key columns are technical row identities and are never changed.** This
allows them to be kept out of the SET clause of updates, and updates on
referenced tables no longer affect the locking behaviour via foreign keys — even
without an index.

The author adds a verification task: *Verify that your ORM-frameworks supports
skipping primary key columns from update.* Not every framework can do this.

## Open despite the decision (implementation risks)

- **Deletes remain the standard case for an index.** The decision requires
  knowing the DML load per referenced table — via `DBA_TAB_MODIFICATIONS`, see
  [[index-usage-monitoring]]. Without that measurement the decision quickly turns
  into a new, inverted dogma.
- **The ORM check is unresolved.** Whether the frameworks in use actually keep
  primary key columns out of updates has to be verified per system.
- **Only 11.2, 12.1 and 19.3 were tested.** No measurement exists for 21c and
  23ai; the rationale rests on releases that are in part well behind the current
  state.
- **If you do index after all, the column structure has to be right** — otherwise
  the index does not act as protection, see the rule in [[foreign-key-locks]].

## Provenance

- Position and rationale come from the blog post of **2016-11-25** ("Clarify
  myths of indexing foreign key constraints on Oracle-DB"), confirmed and
  extended in the post of **2019-12-27**. Both in [[blog-indexing]].
- This is the blog author's reasoned position, not a committee decision. The post
  of 2016-11-25 explicitly invites disagreement: *"If you don't agree with this
  perspective on indexing foreign keys please share your arguments."*
- Ingested into the wiki on 2026-10-01.

## Relationships

- Mechanics and measurements: [[foreign-key-locks]]
- Placement among the four roles: [[indexing]]
- Verification methods: [[index-usage-monitoring]]

## Sources

- [[blog-indexing]]
