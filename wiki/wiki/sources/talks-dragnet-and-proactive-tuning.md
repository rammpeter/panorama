---
title: Talks on dragnet investigation and proactive tuning
type: source
status: maintained
tags: [panorama, dragnet, tuning]
created: 2026-10-04
updated: 2026-10-04
sources: [speakerdeck.md, speakerdeck/2018-11_DOAG-Dresden_Systematische_Rasterfahndung_nach_Performance-Antipattern.pdf, speakerdeck/2026-05_DOAG_Datenbank_Firefighting_or_Fixing_Root_Causes.pdf]
---

# Talks on dragnet investigation and proactive tuning

Two decks from [[rammpeter-talks]], eight years apart, making the same argument:
performance work should not wait for the incident. Both use [[dragnet]] as the
instrument.

## The decks

| Date | Title | Venue / language | Slides | File in `raw/speakerdeck/` |
|---|---|---|---|---|
| 2018-11 | Systematische Rasterfahndung nach Performance-Antipattern | DOAG Dresden, German | 19 | `2018-11_DOAG-Dresden_Systematische_Rasterfahndung_nach_Performance-Antipattern.pdf` |
| 2026-05 | DB Performance Tuning: Firefighting or Fixing Root Causes? | DOAG Datenbank, English | 26 | `2026-05_DOAG_Datenbank_Firefighting_or_Fixing_Root_Causes.pdf` |

## Key points

**Two ways of optimising** (2018 slide 4, 2026 slide 7). Event-driven work has a
high effect per measure and low cost, but uses the potential only in spots and
may leave hardware and licences oversized. Preventive work uses the potential
broadly, with diminishing returns per measure and rising effort
→ [[proactive-performance-tuning]].

**The dragnet idea** (2018 slide 5). Express the *recognition* of a problem as a
SQL statement over the dictionary, the SGA views and the AWR history, so that
every further occurrence of a problem analysed once is found, weighted by
relevance. The stated limit: it covers "only the topics I was personally
confronted with in projects" → [[dragnet]].

**It is not a to-do list generator** (2018 slide 6). Expert judgement of each
suggestion is "mandatory", including recognising and discarding hits without
practical relevance. The links from each hit into object structure, SQL, plans
and ASH exist for that judgement.

**The catalogue grew**: "just under 100" aspects in 2018, "140+ predefined
checks" in 2026.

**The SQL is available without Panorama** (2018 slide 8, 2026 slide 11), at
<https://rammpeter.github.io/oracle_performance_tuning.html>.

**Worked examples, 2018**: indexes with only one or few key values (1.2.2);
index compression by leaf blocks (1.1.3); doubly indexed columns (1.2.3); unused
indexes by monitoring (1.2.4); indexes repeating the partition key (1.2.8);
parallel plans forced to serial (2.2.8); changing plans in history (2.6);
`TABLE ACCESS BY INDEX ROWID` with additional filters (1.11).

**Worked examples, 2026**: index compression (1.1.2–1.1.4); redundant indexes
(1.2.3); unused indexes (1.2.4); foreign keys with a missing index (1.7.1) and
with an unnecessary one (1.2.6); `PCT_FREE` > 0 without updates (1.2.10); table
access with additional filters (1.15); full scans with small cardinality
(2.1.3); frequent access to small objects (2.4.2); unnecessarily high fetch
count (2.4.3); missing bind variables (4.1.1–4.1.5); JDBC statement cache not
used (4.2.2) → [[dragnet]], [[proactive-performance-tuning]].

**Three of the 2026 examples are advice for application developers**, not DBAs:
cache small master data in the application, fetch in bulk
(`setFetchSize`, `defaultRowPrefetch`), and switch on the JDBC statement cache,
which Oracle's driver leaves off by default
→ [[proactive-performance-tuning]].

## Impact on the wiki

- New: [[proactive-performance-tuning]].
- [[dragnet]] — the rationale, the size over time, the standalone SQL list, more
  entries, and direct evidence that numbering shifts.
- [[indexing]], [[index-compression]], [[foreign-key-locks]] — examples.
- [[bind-variables-and-cursor-sharing]] — a probable slip in the 2026 deck, see
  below.

## Changes over time and disagreements

- **Numbering shifts — confirmed by the source.** "TABLE ACCESS BY INDEX ROWID
  with additional filter" is point **1.11** in 2018 and **1.15** in 2026. That
  settles the question raised in [[dragnet]] and concluded from the code in
  [[panorama-request-and-rendering]].
- **Index compression saving.** 2018: "by 1/4 to 1/3". 2026: "up to 30 % or
  more". Compare [[index-compression]].
- **Slip in the source, confirmed by the author on 2026-10-04.** The 2026 deck (slide 22) says "`cursor_sharing=EXACT` can
  reduce the problem, but with other side effects". `EXACT` is the default and
  changes nothing; the blog and
  [[cursor-sharing-force-is-no-substitute]] speak of `FORCE`. The slide
  should read `FORCE`; the archived PDF is left unchanged.
- The 2018 deck links a WordPress blog address; later decks the Blogspot one.

## Open questions

- Which of the 140+ checks need AWR or ASH, and which run on dictionary and SGA
  alone?
- The 2026 examples were "live demonstrated on a not yet fully optimized
  production system" — the slides contain no results.

## Source files

`raw/speakerdeck.md` (pointer); PDFs downloaded on 2026-10-03 into
`raw/speakerdeck/`.
