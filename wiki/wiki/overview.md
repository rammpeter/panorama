---
title: Overview
type: overview
status: draft
tags: [top-level]
created: 2026-09-30
updated: 2026-10-05
sources: [blog.md, posts/, panorama-repository.md, speakerdeck.md, speakerdeck/, rammpeter.github.io.md, rammpeter.github.io/]
---

# Overview

This wiki collects knowledge about **[[panorama]]** — the tool for performance
analysis of Oracle databases — and about the **Oracle expertise** its analyses
rest on. The two halves sit side by side deliberately: almost every Panorama
feature implements an Oracle concept, and almost every Oracle concept has a view
in Panorama.

Full catalogue of all pages: [[index]].

## Structure

The wiki is divided by audience into two categories:

- **Usage** (`wiki/usage/`) — how to analyse an Oracle database with Panorama:
  features, workflows, techniques and the Oracle behaviour behind them. Two
  pages give the way in: [[panorama-menu-overview]] lists every menu entry with
  its purpose and its page, and [[panorama-analysis-workflows]] describes how an
  analysis is laid out and how the interface is driven. The core topics below
  are its content.
- **Development** (`wiki/development/`) — how Panorama itself works:
  architecture, internal mechanisms, design decisions. Entry point:
  [[panorama-architecture]].

Alongside sit the source summaries (`wiki/sources/`) and kept answers
(`wiki/syntheses/`).

## Core topics

### Getting started with the tool

[[panorama-privileges]] says which grants the login user needs (the minimum is
`SELECT ANY DICTIONARY`), [[panorama-operations]] how to start and configure the
server. An analysis then runs along **three pillars** — sessions
([[session-list]], [[session-waits]]), SQL ([[sql-area]]) and objects
([[describe-object]], [[db-cache-usage]]) — each looked at in its current state
or retrospectively ([[panorama-analysis-workflows]]). Checks of the setup start
at [[database-configuration]]; Oracle's own reports are delivered by
[[genuine-oracle-reports]].

### The stance: do not wait for the incident

[[proactive-performance-tuning]] frames the whole usage half: find every
occurrence of a known problem pattern system-wide, rank the hits, fix the cheap
ones before anyone complains. [[dragnet]] is the instrument; the catalogue has
grown from just under 100 checks (2018) to more than 140 (2026).

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
Worked out as a procedure: [[finding-skipped-index-columns]]. For an index that
must stay, two ways to make it small: [[function-based-indexes]] (index only
the rows that matter) and [[index-compression]].

### Mastering execution plans

It is not the bad plan that is the risk but the changing one —
[[execution-plans]]. It can be controlled without changing the application:
[[sql-plan-management]] (the **SQL patch** is the licence-free lever),
[[optimizer-hints]] (since 19c the database reveals what it did with them),
[[sql-translation-framework]] for the whole text, and
[[optimizer-diagnostics]] when the plan alone does not suffice. One concrete
technique: [[view-pushed-predicate]]. The four ways to intervene, side by side
with their licences: [[sql-plan-management]].

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
[[oltp-compression]] within the wider comparison [[advanced-compression]]
(position: [[monitor-migrated-rows-under-advanced-compression]]), and
[[partitioning]] with [[partition-pruning]] and
[[interval-partitions-rolling-window]].

### How Panorama is built

The development half, from the source code ([[panorama-source-code]]).
[[panorama-architecture]] is the map: a Rails application on JRuby with no
database of its own. [[panorama-connection]] opens Oracle sessions per request
and pools them outside ActiveRecord
([[own-connection-pool-outside-activerecord]]). Every statement passes the
[[pack-license-filter]], which is also what makes the sampler interchangeable
with AWR; the sampler itself is threads in the server plus a self-maintained
schema ([[panorama-sampler-internals]]). Views are fragments rendered through
one grid generator ([[panorama-request-and-rendering]]). Identity is a cookie,
state a file store, passwords encrypted twice
([[panorama-client-state-and-security]],
[[route-state-changing-actions-post-only]]). Settings:
[[panorama-configuration]]; from commit to JAR:
[[panorama-build-test-and-release]].

## State

The main source is [[rammpeter-blog]] with 74 posts from 2012 to 2026 — **fully
ingested**, organised into eleven thematic blocks in `wiki/sources/`. The posts
themselves are archived in `raw/posts/`.

The second source is the **source repository** itself
([[panorama-source-code]]), read at commit `d887d8d3` (version 2.19.26). It is a
pointer to living code, not a frozen document.

The third source is the author's **conference talks** ([[rammpeter-talks]]):
14 slide decks from 2016 to 2026, archived in `raw/speakerdeck/` and summarised
in seven `talks-…` source pages. They arrange what the blog establishes and add
measurements (compression), a technique ([[function-based-indexes]]) and the
inside view of the sampler.

The fourth source is **Panorama's website** ([[rammpeter-github-io]]): landing
page, sampler page, an unfinished usage guide and a menu overview generated from
the source code, fetched twice on 2026-10-05 (the site was republished in between) and archived
in `raw/rammpeter.github.io/`. It supplied the menu structure, the grants and the
operating instructions, and is in a few places older than the code.

All pointers in `raw/` are now ingested.

## Open questions

- **The development pages age with the code.** Their source is a pointer to the
  repository, not a frozen file; they are true for commit `d887d8d3`. The domain
  controllers — the bulk of the code — were not read.
- **The new compression rule has no routine yet.** [[monitor-migrated-rows-under-advanced-compression]]
  replaced the old "no updates" rule on 2026-10-04, but neither source says how
  often to check for migrated rows or when to act.
- **Chart values are approximate.** The compression measurements in
  [[advanced-compression]] and [[index-compression]] were read off bar charts.
- **Code and blog disagree in four places** (editions that may choose a pack
  licence, environment variable names, the `/Panorama` path, the oldest tested
  release) — listed in [[panorama-source-code]].
- **Screenshots are missing throughout.** The blog feed does not supply them, and
  the screenshots on the talk slides were not described. The
  Panorama how-tos and the execution plan posts in particular carry part of their
  message through images.
- **Version states go stale.** Many findings are tied to releases (11.2, 12.1,
  19.x). For 21c and 23ai there are usually no measurements.
- **Menu pages are missing for 58 of 124 menu entries.** The schema asks for a
  page per menu entry; the website gives most entries only one line. The
  repository is the source that could fill them ([[panorama-menu-overview]]).
- **The website's usage guide has known slips** (release "11.4", menu names
  that differ from the generated overview, two `CREATE INDEX` examples with a
  missing parenthesis) and is unfinished; the landing page still says "more
  than 100" dragnet checks. Two other points found at the first fetch were
  corrected on the website the same day — see [[rammpeter-github-io]].
- **Two functions required Adobe Flash** (SQL Monitor report, Performance Hub).
  For the SQL Monitor report the website now describes CSS and JavaScript
  ([[sql-monitor]]); for the Performance Hub the current state is not evidenced.
- Which Oracle concepts still deserve pages of their own? Wait event classes and
  optimizer statistics beyond the extended statistics are so far covered only in
  scattered form.
