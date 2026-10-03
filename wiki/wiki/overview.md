---
title: Overview
type: overview
status: draft
tags: [top-level]
created: 2026-09-30
updated: 2026-10-02
sources: [blog.md, posts/]
---

# Overview

This wiki collects knowledge about **[[panorama]]** — the tool for performance
analysis of Oracle databases — and about the **Oracle expertise** its analyses
rest on. The two halves sit side by side deliberately: almost every Panorama
feature implements an Oracle concept, and almost every Oracle concept has a view
in Panorama.

Full catalogue of all pages: [[index]].

## Core topics

### The data foundation and its limits

[[awr]] and [[ash]] carry most retrospective analyses. Both have limits you need
to know: ASH records **no idle waits** — a busy session can appear idle — the
one-second interval is too coarse for short events, and the retention does not
reach far enough for year-on-year comparisons
([[long-term-trend-analysis]]). For establishing a connection ASH is entirely
blind; the [[audit-trail]] helps there.

Over all of it stands **[[management-pack-licensing]]**: what you are allowed to
evaluate has a say in which analysis is possible. [[panorama-sampler]] is the
licence-free fallback — and Panorama evaluates both sources in the same place.

### Indexes: which ones does a database really need?

The most fully worked-out strand. [[indexing]] with the **four roles** is the
framework; hanging off it are [[index-usage-monitoring]] (and its blind spots),
[[foreign-key-locks]], [[index-compression]], [[index-access-paths]] and
[[extended-statistics]]. The author's answer is uncomfortable: often considerably
fewer indexes than are present, see [[do-not-blanket-index-foreign-keys]].
Worked out as a procedure: [[finding-skipped-index-columns]].

### Mastering execution plans

It is not the bad plan that is the risk but the changing one —
[[execution-plans]]. It can be controlled without changing the application:
[[sql-plan-management]] (the **SQL patch** is the licence-free lever),
[[optimizer-hints]] (since 19c the database reveals what it did with them),
[[sql-translation-framework]] for the whole text, and
[[optimizer-diagnostics]] when the plan alone does not suffice. One concrete
technique: [[view-pushed-predicate]].

### What applications do to the database

[[bind-variables-and-cursor-sharing]] — the longest-lived problem in the blog,
with consequences reaching into [[sga-memory-management]]; the obvious shortcut
is not one ([[cursor-sharing-force-is-no-substitute]]). Plus
[[short-lived-sessions]] (around 4 % of a CPU core per connection per second),
[[deterministic]] (a million function calls instead of one) and
[[sequence-caching]].

### Locks and serialisation

[[blocking-locks]] — the root session counts, not the leaf. Plus
[[foreign-key-locks]] as an avoidable cause, [[library-cache-contention]] as
blocking on a structure rather than on data, and [[cross-table-uniqueness]] as a
case where serialisation is induced deliberately.

### Storage and operations

[[tablespace-fragmentation]] (free space is not usable space),
[[storage-reorganisation]], [[temp-usage]], [[redo-logs]],
[[oltp-compression]] and [[partitioning]] with [[partition-pruning]] and
[[interval-partitions-rolling-window]].

## State

The main source is [[rammpeter-blog]] with 74 posts from 2012 to 2026 — **fully
ingested**, organised into eleven thematic blocks in `wiki/sources/`. The posts
themselves are archived in `raw/posts/`.

## Open questions

- **Panorama's architecture** is so far known only from the repository, not from
  a source in `raw/`: Rails on JRuby, a connection established per request, no
  persistent database of its own. There is no solid source for that.
- **Screenshots are missing throughout.** The feed does not supply them. The
  Panorama how-tos and the execution plan posts in particular carry part of their
  message through images.
- **Version states go stale.** Many findings are tied to releases (11.2, 12.1,
  19.x). For 21c and 23ai there are usually no measurements.
- **Two functions required Adobe Flash** (SQL Monitor report, Performance Hub) —
  discontinued since the end of 2020, current state not evidenced.
- Which Oracle concepts still deserve pages of their own? Wait event classes and
  optimizer statistics beyond the extended statistics are so far covered only in
  scattered form.
