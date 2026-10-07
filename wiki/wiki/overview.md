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

This wiki collects knowledge about **[Panorama](usage/panorama.md)** — the tool for performance
analysis of Oracle databases — and about the **Oracle expertise** its analyses
rest on. The two halves sit side by side deliberately: almost every Panorama
feature implements an Oracle concept, and almost every Oracle concept has a view
in Panorama.

Full catalogue of all pages: [index](../index.md).

## Structure

The wiki is divided by audience into two categories:

- **Usage** (`wiki/usage/`) — how to analyse an Oracle database with Panorama:
  features, workflows, techniques and the Oracle behaviour behind them. Two
  pages give the way in: [Panorama menu overview](usage/panorama-menu-overview.md) lists every menu entry with
  its purpose and its page, and [Analysis workflows in Panorama](usage/panorama-analysis-workflows.md) describes how an
  analysis is laid out and how the interface is driven. The core topics below
  are its content.
- **Development** (`wiki/development/`) — how Panorama itself works:
  architecture, internal mechanisms, design decisions. Entry point:
  [Panorama architecture](development/panorama-architecture.md).

Alongside sit the source summaries (`wiki/sources/`) and kept answers
(`wiki/syntheses/`).

## Core topics

### Getting started with the tool

[Privileges for Panorama](usage/panorama-privileges.md) says which grants the login user needs (the minimum is
`SELECT ANY DICTIONARY`), [Panorama operations](usage/panorama-operations.md) how to start and configure the
server. An analysis then runs along **three pillars** — sessions
([Session list](usage/session-list.md), [Session waits](usage/session-waits.md)), SQL ([SQL area](usage/sql-area.md)) and objects
([Describe object](usage/describe-object.md), [DB cache usage](usage/db-cache-usage.md)) — each looked at in its current state
or retrospectively ([Analysis workflows in Panorama](usage/panorama-analysis-workflows.md)). Checks of the setup start
at [Database configuration](usage/database-configuration.md); Oracle's own reports are delivered by
[Genuine Oracle reports](usage/genuine-oracle-reports.md).

### The stance: do not wait for the incident

[Proactive performance tuning](usage/proactive-performance-tuning.md) frames the whole usage half: find every
occurrence of a known problem pattern system-wide, rank the hits, fix the cheap
ones before anyone complains. [Dragnet Investigation](usage/dragnet.md) is the instrument; the catalogue has
grown from just under 100 checks (2018) to more than 140 (2026).

### The data foundation and its limits

[AWR](usage/awr.md) and [ASH](usage/ash.md) carry most retrospective analyses. Both have limits you need
to know: ASH records **no idle waits** — a busy session can appear idle — the
one-second interval is too coarse for short events, and the retention does not
reach far enough for year-on-year comparisons
([Long-term trend analysis](usage/long-term-trend-analysis.md)). For establishing a connection ASH is entirely
blind; the [Audit trail](usage/audit-trail.md) helps there.

Over all of it stands **[Management pack licensing](usage/management-pack-licensing.md)**: what you are allowed to
evaluate has a say in which analysis is possible. [Panorama Sampler](usage/panorama-sampler.md) is the
licence-free fallback — and Panorama evaluates both sources in the same place.

### Indexes: which ones does a database really need?

The most fully worked-out strand. [Indexing](usage/indexing.md) with the **four roles** is the
framework; hanging off it are [Index usage monitoring](usage/index-usage-monitoring.md) (and its blind spots),
[Foreign keys and locks](usage/foreign-key-locks.md), [Index compression](usage/index-compression.md), [Index access paths](usage/index-access-paths.md) and
[Extended statistics](usage/extended-statistics.md). The author's answer is uncomfortable: often considerably
fewer indexes than are present, see [Do not blanket-index foreign keys](usage/do-not-blanket-index-foreign-keys.md).
Worked out as a procedure: [Finding skipped index columns](syntheses/finding-skipped-index-columns.md). For an index that
must stay, two ways to make it small: [Function-based indexes](usage/function-based-indexes.md) (index only
the rows that matter) and [Index compression](usage/index-compression.md).

### Mastering execution plans

It is not the bad plan that is the risk but the changing one —
[Execution plans](usage/execution-plans.md). It can be controlled without changing the application:
[SQL plan management](usage/sql-plan-management.md) (the **SQL patch** is the licence-free lever),
[Optimizer hints](usage/optimizer-hints.md) (since 19c the database reveals what it did with them),
[SQL Translation Framework](usage/sql-translation-framework.md) for the whole text, and
[Optimizer diagnostics](usage/optimizer-diagnostics.md) when the plan alone does not suffice. One concrete
technique: [VIEW PUSHED PREDICATE](usage/view-pushed-predicate.md). The four ways to intervene, side by side
with their licences: [SQL plan management](usage/sql-plan-management.md).

### What applications do to the database

[Bind variables and cursor sharing](usage/bind-variables-and-cursor-sharing.md) — the longest-lived problem in the blog,
with consequences reaching into [SGA memory management](usage/sga-memory-management.md); the obvious shortcut
is not one ([cursor_sharing = FORCE is no substitute for prepared statements](usage/cursor-sharing-force-is-no-substitute.md)). Plus
[Short-lived sessions](usage/short-lived-sessions.md) (around 4 % of a CPU core per connection per second),
[DETERMINISTIC](usage/deterministic.md) (a million function calls instead of one) and
[Sequence caching](usage/sequence-caching.md).

### Locks and serialisation

[Blocking locks](usage/blocking-locks.md) — the root session counts, not the leaf. Plus
[Foreign keys and locks](usage/foreign-key-locks.md) as an avoidable cause, [Library cache contention](usage/library-cache-contention.md) as
blocking on a structure rather than on data, and [Cross-table uniqueness](usage/cross-table-uniqueness.md) as a
case where serialisation is induced deliberately.

### Storage and operations

[Tablespace fragmentation](usage/tablespace-fragmentation.md) (free space is not usable space),
[Storage reorganisation](usage/storage-reorganisation.md), [TEMP usage](usage/temp-usage.md), [Redo logs](usage/redo-logs.md),
[OLTP compression](usage/oltp-compression.md) within the wider comparison [Table, index and LOB compression compared](usage/advanced-compression.md)
(position: [Use advanced compression with updates, and monitor migrated rows](usage/monitor-migrated-rows-under-advanced-compression.md)), and
[Partitioning](usage/partitioning.md) with [Partition pruning](usage/partition-pruning.md) and
[Interval partitions and the rolling window](usage/interval-partitions-rolling-window.md).

### How Panorama is built

The development half, from the source code ([Panorama source repository](sources/panorama-source-code.md)).
[Panorama architecture](development/panorama-architecture.md) is the map: a Rails application on JRuby with no
database of its own. [PanoramaConnection](development/panorama-connection.md) opens Oracle sessions per request
and pools them outside ActiveRecord
([Own connection pool outside ActiveRecord](development/own-connection-pool-outside-activerecord.md)). Every statement passes the
[Pack licence filter](development/pack-license-filter.md), which is also what makes the sampler interchangeable
with AWR; the sampler itself is threads in the server plus a self-maintained
schema ([Panorama Sampler internals](development/panorama-sampler-internals.md)). Views are fragments rendered through
one grid generator ([Controllers, routing and rendering in Panorama](development/panorama-request-and-rendering.md)). Identity is a cookie,
state a file store, passwords encrypted twice
([Client state and security in Panorama](development/panorama-client-state-and-security.md),
[Route state-changing actions as POST only](development/route-state-changing-actions-post-only.md)). Settings:
[Panorama configuration](development/panorama-configuration.md); from commit to JAR:
[Building, testing and releasing Panorama](development/panorama-build-test-and-release.md).

## State

The main source is [rammpeter.blogspot.com](usage/rammpeter-blog.md) with 74 posts from 2012 to 2026 — **fully
ingested**, organised into eleven thematic blocks in `wiki/sources/`. The posts
themselves are archived in `raw/posts/`.

The second source is the **source repository** itself
([Panorama source repository](sources/panorama-source-code.md)), read at commit `d887d8d3` (version 2.19.26). It is a
pointer to living code, not a frozen document.

The third source is the author's **conference talks** ([Talks and slide decks by Peter Ramm](usage/rammpeter-talks.md)):
14 slide decks from 2016 to 2026, archived in `raw/speakerdeck/` and summarised
in seven `talks-…` source pages. They arrange what the blog establishes and add
measurements (compression), a technique ([Function-based indexes](usage/function-based-indexes.md)) and the
inside view of the sampler.

The fourth source is **Panorama's website** ([Panorama's website on GitHub Pages](sources/rammpeter-github-io.md)): landing
page, sampler page, an unfinished usage guide and a menu overview generated from
the source code, fetched twice on 2026-10-05 (the site was republished in between) and archived
in `raw/rammpeter.github.io/`. It supplied the menu structure, the grants and the
operating instructions, and is in a few places older than the code.

All pointers in `raw/` are now ingested.

## Open questions

- **The development pages age with the code.** Their source is a pointer to the
  repository, not a frozen file; they are true for commit `d887d8d3`. The domain
  controllers — the bulk of the code — were not read.
- **The new compression rule has no routine yet.** [Use advanced compression with updates, and monitor migrated rows](usage/monitor-migrated-rows-under-advanced-compression.md)
  replaced the old "no updates" rule on 2026-10-04, but neither source says how
  often to check for migrated rows or when to act.
- **Chart values are approximate.** The compression measurements in
  [Table, index and LOB compression compared](usage/advanced-compression.md) and [Index compression](usage/index-compression.md) were read off bar charts.
- **Code and blog disagree in four places** (editions that may choose a pack
  licence, environment variable names, the `/Panorama` path, the oldest tested
  release) — listed in [Panorama source repository](sources/panorama-source-code.md).
- **Screenshots are missing throughout.** The blog feed does not supply them, and
  the screenshots on the talk slides were not described. The
  Panorama how-tos and the execution plan posts in particular carry part of their
  message through images.
- **Version states go stale.** Many findings are tied to releases (11.2, 12.1,
  19.x). For 21c and 23ai there are usually no measurements.
- **Menu pages are missing for 58 of 124 menu entries.** The schema asks for a
  page per menu entry; the website gives most entries only one line. The
  repository is the source that could fill them ([Panorama menu overview](usage/panorama-menu-overview.md)).
- **The website's usage guide has known slips** (release "11.4", menu names
  that differ from the generated overview, two `CREATE INDEX` examples with a
  missing parenthesis) and is unfinished; the landing page still says "more
  than 100" dragnet checks. Two other points found at the first fetch were
  corrected on the website the same day — see [Panorama's website on GitHub Pages](sources/rammpeter-github-io.md).
- **Two functions required Adobe Flash** (SQL Monitor report, Performance Hub).
  For the SQL Monitor report the website now describes CSS and JavaScript
  ([SQL Monitor](usage/sql-monitor.md)); for the Performance Hub the current state is not evidenced.
- Which Oracle concepts still deserve pages of their own? Wait event classes and
  optimizer statistics beyond the extended statistics are so far covered only in
  scattered form.
