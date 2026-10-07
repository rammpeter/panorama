---
title: Management pack licensing
type: concept
status: draft
tags: [core, oracle, licensing]
created: 2026-10-01
updated: 2026-10-05
sources: [blog.md, posts/, panorama-repository.md, speakerdeck.md, speakerdeck/]
---

# Management pack licensing

Some of Oracle's performance data may only be evaluated with a paid licence. The
licence therefore has a say in which analysis is permissible at all — a caveat
that runs through this entire wiki.

## What needs which licence

Collected from several posts:

| Subject | Requirement | Evidenced in |
|---|---|---|
| [AWR](awr.md), [ASH](ash.md) | Enterprise Edition **and** Diagnostics Pack | [Blog series on locks and serialisation](../sources/blog-locks.md) 2020-10-06 |
| [SQL Monitor](sql-monitor.md) | Enterprise Edition and **Tuning Pack** | [Blog series on Panorama as a tool](../sources/blog-panorama-the-tool.md) 2017-12-01 |
| SQL plan baselines, SQL profiles | additional licence | [Blog series on execution plans and the optimizer](../sources/blog-execution-plans.md) 2018-01-14 |
| **SQL patches** | **none** — Standard Edition too | [Blog series on execution plans and the optimizer](../sources/blog-execution-plans.md) 2018-01-14, 2026-06-29 |
| **SQL Diagnostic Report** (`DBMS_SQLDIAG.REPORT_SQL`) | **none** — verified empirically | [Blog series on execution plans and the optimizer](../sources/blog-execution-plans.md) 2025-08-07 |
| [Panorama Sampler](panorama-sampler.md) | **none** — any edition | [Blog series on Panorama as a tool](../sources/blog-panorama-the-tool.md) 2017-11-17 |

> Two findings are especially valuable in practice: **SQL patches** are the
> licence-free way to influence an execution plan, and the **SQL Diagnostic
> Report** delivers, from 19.28, a licence-free combined report containing ASH
> and SQL Monitor data — even though both sources require a licence in their own
> right. The author did not take the latter from the documentation but verified
> it via `DBA_FEATURE_USAGE_STATISTICS` on a fresh 23.9 database.

## How Panorama handles it

([Blog series on Panorama as a tool](../sources/blog-panorama-the-tool.md), 2017-12-01) The licensing model is built into the
workflow: after connecting, **one of four options** must be confirmed before
restricted dictionary data is read.

1. A licence for the Diagnostics Pack **and** the Tuning Pack is held
2. A licence for the Diagnostics Pack, **not** for the Tuning Pack
3. Panorama's own sampler data is used — **no** licence needed
4. No licence **and** no sampler data available

The pre-selection follows the init parameter `control_management_pack_access` of
the target database. Options 1 and 2 are only available for Enterprise Edition —
*so the 2017 post; see the contradiction below.*

**Contradiction (recorded 2026-10-03).** The current code
([Panorama source repository](../sources/panorama-source-code.md), `PackLicense.management_pack_selectable`) is wider
than the post: options 1 and 2 are selectable for **Enterprise and Free** edition
if `control_management_pack_access` contains the pack, and for **Express Edition
unconditionally**. An autonomous database, where the parameter is not set, is
pre-selected as having both packs. The code is the newer source and describes
what Panorama does today; whether the wider offer matches Oracle's licensing
terms for those editions is a separate question the code does not answer.

The enforcement itself — how "every function call results in an error" is
guaranteed — is described in [Pack licence filter](../development/pack-license-filter.md).

**The consequences are hard-wired:**

- Without a confirmed licence, **every** function call that would request
  original AWR data or licence-restricted packages results in an error message.
- With option 3 Panorama **transparently** uses its own sampler data instead of
  the AWR data.
- But: access to AWR tables for which there is **no** corresponding sampler data
  also results in an error message under option 3.

> The last point is the honest one: the sampler does **not** fully replace AWR.
> Where it records nothing, the function stays blocked instead of silently
> showing something wrong.

## Two statements with a shelf life

- The licence statement on the SQL Diagnostic Report rests, among other things,
  on MOS Doc ID 1509192.1, whose last update was in **2022** according to the
  author.
- The assignment in the table above comes from posts between 2017 and 2026.
  Licensing conditions change; the entries are dated, not timeless.

## What the licence costs

List prices per processor as shown in the sampler talks
([Talks on Panorama and the Panorama Sampler](../sources/talks-panorama-and-sampler.md); identical figures in 2022 and 2025):

| | Licence, USD | Support per year (22 %), USD |
|---|---|---|
| Standard Edition 2 | 17,500 | 3,850 |
| Enterprise Edition | 47,500 | 10,450 |
| Diagnostics Pack | 7,500 | 1,650 |
| Enterprise Edition + Diagnostics Pack | 55,000 | 12,100 |

The argument made with it: licensing Enterprise Edition and the pack *only* to
get AWR and ASH more than triples the cost against Standard Edition — the
economic reason for the [Panorama Sampler](panorama-sampler.md). The Advanced Compression Option is
put at about a quarter of the Enterprise Edition price
([Table, index and LOB compression compared](advanced-compression.md)).

**Refinements to the table at the top**, from [Talk on influencing execution plans without code changes](../sources/talks-sql-plan-management.md): a
SQL plan baseline needs Enterprise Edition, and the Tuning Pack only for creating
it from AWR data; a SQL profile needs Enterprise Edition with Diagnostics *and*
Tuning Pack; the SQL translation framework is listed as Enterprise Edition
→ [SQL plan management](sql-plan-management.md).

## Relationships

- The licence-free fallback: [Panorama Sampler](panorama-sampler.md), and for year-on-year
  comparisons [Long-term trend analysis](long-term-trend-analysis.md).
- Concepts affected: [AWR](awr.md), [ASH](ash.md), [SQL Monitor](sql-monitor.md), [Blocking locks](blocking-locks.md),
  [Index access paths](index-access-paths.md), [Estimating network latency from ASH](network-latency-from-ash.md), [Partition pruning](partition-pruning.md),
  [Parallel execution](parallel-execution.md).
- The licence-free lever on execution plans: [SQL plan management](sql-plan-management.md).
- The other gate besides the licence — the grants a function needs:
  [Privileges for Panorama](panorama-privileges.md). Oracle's own reports: [Genuine Oracle reports](genuine-oracle-reports.md).

## Open questions

- Editions: the post of 2017 and the current code disagree on who may choose
  options 1 and 2 (see above). Which is intended?
- What exactly does the sampler cover and what not? The boundary is now known in
  principle — the sampler's table list, see [Panorama Sampler internals](../development/panorama-sampler-internals.md) — but
  no list of affected functions exists.
- Does the licensing situation differ in cloud offerings (Autonomous Database,
  Exadata Cloud Service)? None of the posts covers that.

## Sources

- [Blog series on Panorama as a tool](../sources/blog-panorama-the-tool.md)
- [Blog series on execution plans and the optimizer](../sources/blog-execution-plans.md)
- [Blog series on locks and serialisation](../sources/blog-locks.md)
- [Blog series on indexing](../sources/blog-indexing.md)
- [Panorama source repository](../sources/panorama-source-code.md)
- [Talks on Panorama and the Panorama Sampler](../sources/talks-panorama-and-sampler.md)
- [Talk on influencing execution plans without code changes](../sources/talks-sql-plan-management.md)
