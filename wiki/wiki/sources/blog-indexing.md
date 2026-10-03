---
title: Blog series on indexing
type: source
status: maintained
tags: [index, oracle]
created: 2026-10-01
updated: 2026-10-02
sources: [blog.md, posts/]
---

# Blog series on indexing

Eight posts from [[rammpeter-blog]] between 2016 and 2026 that together develop
one continuous thesis: **most Oracle databases carry indexes nobody needs — and
getting rid of them is a large, surprisingly low-risk lever.** The posts supply
the procedure, the measurement technique and the counter-check against the common
objections.

## The posts

| Date | Title | Focus |
|---|---|---|
| 2016-08-17 | Generate recommendation lists for index compression on Oracle-DB | [[index-compression]] |
| 2016-11-25 | Clarify myths of indexing foreign key constraints on Oracle-DB | [[foreign-key-locks]], [[do-not-blanket-index-foreign-keys]] |
| 2017-10-12 | Oracle-DB: Identify unused indexes | [[index-usage-monitoring]] |
| 2019-12-27 | Oracle-DB: Identify non-relevant indexes for secure deletion | [[indexing]] – the four roles |
| 2023-03-27 | Requirements for a multi-column index for protecting foreign key constraints | [[foreign-key-locks]] |
| 2024-08-15 | Apparent cardinality problem with expressions indexed by a function based index | [[extended-statistics]] |
| 2026-06-03 | Find problematic iteration at skipped columns for INDEX RANGE SCAN | [[index-access-paths]] |
| 2026-07-02 | Check if an index is used in SQL Plan Management directives or optimizer hints | [[index-usage-monitoring]] |

The post of 2019-12-27 is the anchor of the series; the one of 2026-07-02 is
explicitly marked by the author as an addition to it ("Addition 2026-07").

## Key points

**The scale of it.** In practice there are systems where more than 50 % of the
storage is taken up by indexes without any productive relevance (2019-12-27,
likewise 2016-11-25 and 2017-10-12).

**Why nobody touches it anyway.** The author gives four reasons: there is no role
in the project that would own this task; DBAs do not know the application logic
of the software; developers lack the knowledge and the tooling for a reliable
assessment; and "never touch a running system" — whoever drops an index can burn
their fingers (2019-12-27).

**The four roles.** An index can have exactly four jobs: optimise access from
user SQL, guarantee uniqueness, protect a foreign key, establish structural
identity for partition exchange. If it fulfils none of them, it can go. This is
the checklist the whole series builds on (2019-12-27) → [[indexing]].

**The measurement technique has blind spots.** `ALTER INDEX … MONITORING USAGE`
only records direct SQL, not the database's own recursive access — so precisely
not the foreign key check. `DBA_Index_Usage` from 12.2 is more convenient but
works by sampling and also counts `GATHER_INDEX_STATS` as usage; it therefore
cannot safely rule usage out (2017-10-12, 2019-12-27)
→ [[index-usage-monitoring]].

**Foreign keys do not need blanket indexing.** The post of 2016-11-25 explicitly
contradicts the widespread dogma and backs that up with eight locking scenarios
across releases 11.2, 12.1 and 19.3
→ [[do-not-blanket-index-foreign-keys]].

**If you do index, the column structure matters.** An index is only accepted as
protection for a multi-column foreign key if it contains *all* constraint columns
as its *leading* columns — their order among themselves is irrelevant, additional
columns behind them are allowed, in between or in front of them are not
(2023-03-27, seven test scenarios) → [[foreign-key-locks]].

**An INDEX RANGE SCAN can be as expensive as a SKIP SCAN.** If middle columns of
a multi-column index are not used as access criteria, execution iterates over
their distinct values — in the worst case millions of buffer gets for a single,
inconspicuous index access (2026-06-03) → [[index-access-paths]].

**A function based index without statistics has no effect.** Creating a function
based index also creates an extended statistic, but it is only populated with
values at the next `GATHER_TABLE_STATS`. Until then the optimizer estimates the
cardinality with a flat *rows/100* and does not choose the index — and
`DBA_Tab_Modifications` gives no hint that an analysis would be needed
(2024-08-15) → [[extended-statistics]].

## Impact on the wiki

Newly created: [[indexing]], [[index-usage-monitoring]],
[[foreign-key-locks]], [[index-compression]], [[index-access-paths]],
[[extended-statistics]], the decision page
[[do-not-blanket-index-foreign-keys]] and the entity [[dragnet]].

Extended: [[panorama]] (the author's self-description, its role in index
analysis), [[ash]] and [[management-pack-licensing]] (cross-references to
[[index-access-paths]], which requires the Diagnostics Pack).

## Notes on the evidence

**A revised conclusion.** In the post of 2024-08-15 the author first treats the
optimizer's behaviour as a bug ("I tended to treat this behaviour as a bug at
this time") and only finds the real cause after digging deeper. The page
[[extended-statistics]] records only the revised version as fact; the first
assessment is noted there as superseded.

**Documentation vs. observation.** The post of 2019-12-27 notes that the Oracle
documentation up to 19c requires the status `MONITORING=YES` for
`DBA_TAB_MODIFICATIONS`, while in reality DML operations are recorded from
release 11 onwards even with `NOMONITORING`. Recorded as a divergence in
[[index-usage-monitoring]].

## Source files

`raw/posts/14-*`, `16-*`, `27-*`, `42-*`, `50-*`, `59-*`, `71-*`, `73-*`

`raw/blog.md` contains only the pointer to <https://rammpeter.blogspot.com>; the
texts were fetched on 2026-10-01 via the Atom feed and archived in `raw/posts/`.
