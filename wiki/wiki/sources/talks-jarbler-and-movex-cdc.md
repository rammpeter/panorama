---
title: Talks on Jarbler and MOVEX CDC
type: source
status: maintained
tags: [tool, architecture]
created: 2026-10-04
updated: 2026-10-04
sources: [speakerdeck.md, speakerdeck/2025-05_Jarbler.pdf, speakerdeck/2022-05_MOVEX_CDC_DOAG_Database_en.pdf]
---

# Talks on Jarbler and MOVEX CDC

Two decks from [[rammpeter-talks]] about tools by the same author that are *not*
Panorama. Both are within the wiki's scope as related tools: Jarbler because Panorama
is packaged with it, MOVEX CDC because it shares Panorama's technical base and
contains Oracle design decisions worth keeping.

## The decks

| Date | Title | Venue / language | Slides | File in `raw/speakerdeck/` |
|---|---|---|---|---|
| 2022-05 | MOVEX Change Data Capture | DOAG Database, English | 25 | `2022-05_MOVEX_CDC_DOAG_Database_en.pdf` |
| 2025-05 | Jarbler: Run a Ruby application as Java jar file | English | 7 | `2025-05_Jarbler.pdf` |

## Key points — Jarbler

**What it is** (slide 4): packs an existing Ruby application into a
self-starting Java JAR, based on JRuby, so that the target machine needs no Ruby
environment; preconfigured for Rails → [[jarbler]].

**Minimal use** (slide 5): `jarble config` generates `config/jarble.rb`; set
`executable`, `includes`, `jar_name`; `jarble` builds; `java -jar` runs.

**Honest about the rough edges** (slide 6). A fresh Rails 8.0.2 application did
not start from the JAR — the `puma` gem was ignored "because it is missing
extensions". With Rails 6.1 and JRuby 9.4 it worked after adjustments:
`concurrent-ruby` pinned to 1.3.4, Webpacker removed, `sass-rails` removed
because `sassc` has native extensions. And `rails server` "did not react in
production mode — known issue, but forgot solution" → [[jarbler]].

## Key points — MOVEX CDC

**What it is** (slides 4–5): an open-source (GPL3) tool that captures insert,
update and delete events in a relational database and transfers them as JSON to
Kafka; configured per table, column and event type → [[movex-cdc]].

**Why triggers instead of log mining** (slide 6). Log-based tools do not burden
the original transaction, but to survive an unavailable target automatically the
transaction logs must be kept for the longest assumed outage — "usually at least
3 days". For a small share of relevant events in a large OLTP system that is
disproportionate → [[movex-cdc]].

**The design** (slides 7, 14, 19): a trigger writes the event into a staging
table in MOVEX CDC's own schema — no dependency of the business transaction on
anything outside the database; worker threads transfer asynchronously to Kafka.
The trigger is a compound trigger that buffers up to 1,000 JSON records in
memory and flushes them in bulk.

**The staging table is tuned for inserts** (slides 21–22). On Enterprise Edition
with partitioning: an interval-partitioned table **without any index**, read by
full scan, with processed partitions dropped. On Standard Edition: a heap table
with an index on `ID`, whose high water mark has to be reset by hand from time
to time → [[movex-cdc]], [[interval-partitions-rolling-window]],
[[storage-reorganisation]].

**Work distribution by row locks** (slide 17):
`SELECT … FOR UPDATE SKIP LOCKED` assigns events to worker threads. Order is
guaranteed only per key, by hashing the key to one thread.

**Measured throughput** (slide 23): 820,000 events per minute with three worker
threads and JSON under 4 KB. From 4 KB upward Oracle stores the payload as a
CLOB, "significantly slower".

**Same technical base as Panorama** (slides 12, 24): Ruby on Rails on JRuby in a
Docker container; configuration by file or environment variables; the schema
initialises itself at container start → [[panorama-architecture]].

## Impact on the wiki

- New: [[jarbler]] (development), [[movex-cdc]] (usage, as an external tool).
- [[panorama-build-test-and-release]] — link to the Jarbler page.
- [[interval-partitions-rolling-window]] — a second, independent use of the
  pattern.

## Changes over time and disagreements

- The Jarbler deck shows a Rails 8.0 application failing to start from a JAR in
  May 2025. Panorama itself is on Rails 8.1 and ships as a JAR built with Jarbler
  ([[panorama-source-code]]). The problem was evidently solved for Panorama —
  among other things by excluding gems (`excluded_gems.txt`); the deck does not
  say how.

## Open questions

- ~~Is MOVEX CDC within the wiki's scope?~~ Settled by the author on 2026-10-04:
  it can be mentioned. Its repository is now at
  <https://gitlab.com/osp-silver/oss/movex-cdc>, not at the address on the
  slides.
- What was the solution to "rails server did not react in production mode"?

## Source files

`raw/speakerdeck.md` (pointer); PDFs downloaded on 2026-10-03 into
`raw/speakerdeck/`.
