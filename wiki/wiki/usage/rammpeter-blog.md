---
title: rammpeter.blogspot.com
type: entity
subtype: external
status: draft
tags: [source]
created: 2026-10-01
updated: 2026-10-04
sources: [blog.md, posts/, speakerdeck.md, speakerdeck/]
---

# rammpeter.blogspot.com

The blog of Panorama's author, titled "Peter Ramm's Oracle performance analysis
stuff". 74 posts between 2012-05-14 and 2026-09-16, throughout in English. The
single most important source of this wiki.

## Summary

The blog has two kinds of post, which often mix within the same text:

- **Oracle mechanics** (label "Analyze performance issue", 27 posts): a
  behaviour of the database is taken apart, mostly with ready-made SQL against
  `V$`/`GV$` and `DBA_HIST_*` views, frequently with reproduced test scenarios
  across several Oracle releases.
- **Panorama how-tos** (label "Panorama How-To", 33 posts): how to click through
  the same analysis in [Panorama](panorama.md), often as a continuation of the mechanics
  part in the same post.

In addition there are seven posts with ready-made PL/SQL building blocks (label
"Code templates").

The typical structure: a concrete problem from practice, the measurement, the
interpretation, then the route to a remedy — and at the end the note that
Panorama can do it more conveniently. Several posts explicitly take a position
against widespread assumptions and back it up with reproducible tests.

## Relationships

- Written by the author of [Panorama](panorama.md); the tool is the means or the subject in
  roughly half the posts.
- Recurring data foundations: [AWR](awr.md), [ASH](ash.md).
- Recurring caveat: [Management pack licensing](management-pack-licensing.md) — several posts point out
  specifically that an evaluation requires Enterprise Edition plus the
  Diagnostics Pack.
- The author's conference talks, which arrange what the posts establish:
  [Talks and slide decks by Peter Ramm](rammpeter-talks.md).

## State of ingestion

**Fully ingested** (all 74 posts), organised into eleven thematic blocks:

| Source page | Posts |
|---|---|
| [Blog series on indexing](../sources/blog-indexing.md) | 8 |
| [Blog series on execution plans and the optimizer](../sources/blog-execution-plans.md) | 9 |
| [Blog series on bind variables and SQL text](../sources/blog-bind-variables.md) | 3 |
| [Blog series on locks and serialisation](../sources/blog-locks.md) | 4 |
| [Blog series on sessions, connections and the network](../sources/blog-sessions-and-connections.md) | 8 |
| [Blog series on system load and monitoring](../sources/blog-system-load.md) | 7 |
| [Blog series on the audit trail](../sources/blog-audit-trail.md) | 5 |
| [Blog series on storage, tablespaces and redo](../sources/blog-storage.md) | 6 |
| [Blog series on partitioning and parallel processing](../sources/blog-partitioning.md) | 5 |
| [Blog series on caching and PL/SQL](../sources/blog-caching-and-plsql.md) | 5 |
| [Blog series on Panorama as a tool](../sources/blog-panorama-the-tool.md) | 14 |

## Posts

Legend: **bold** = ingested (all of them).

1. 2012-05-14 – [Measure average system load on oracle database instance](https://rammpeter.blogspot.com/2017/03/measure-average-system-load-on-oracle.html)
2. 2012-05-15 – [Measure average I/O-load and CPU-usage on Oracle database instance](https://rammpeter.blogspot.com/2017/03/measure-average-io-load-and-cpu-usage.html)
3. 2013-05-14 – [Caching of frequently used static master data (pre 11g)](https://rammpeter.blogspot.com/2017/03/caching-of-frequently-used-static.html)
4. 2013-05-17 – [Caching of frequently used static master data (post 11g, using RESULT_CACHE)](https://rammpeter.blogspot.com/2017/03/caching-of-frequently-used-static_25.html)
5. 2013-09-17 – [Analyze affected objects for wait event “library cache: mutex X”](https://rammpeter.blogspot.com/2017/03/analyze-affected-objects-for-wait-event.html)
6. 2014-04-28 – [Create SQL trace for unique application by DBMS_MONITOR](https://rammpeter.blogspot.com/2017/03/create-sql-trace-for-unique-application.html)
7. 2014-06-03 – [Monitor/sample values from gv$SesStat in history: monitor transaction count per session in history](https://rammpeter.blogspot.com/2017/03/monitorsample-values-from-gvsesstat-in.html)
8. 2014-07-09 – [Set script name as module/action in V$Session if SQL*Plus-session starts](https://rammpeter.blogspot.com/2014/07/set-script-name-as-moduleaction-in.html)
9. 2016-03-20 – [Panorama: Fix changed execution plan with SQL plan baseline](https://rammpeter.blogspot.com/2016/03/panorama-fix-changed-execution-plans.html)
10. 2016-03-20 – [Panorama: User is enabled to add personal SQL to dragnet list](https://rammpeter.blogspot.com/2016/03/panorama-user-is-enabled-to-add.html)
11. 2016-03-23 – [Panorama: How to identify root cause after “ORA-1652: unable to extend temp segment”](https://rammpeter.blogspot.com/2016/03/panorama-how-to-identify-root-cause.html)
12. 2016-04-27 – [Panorama: How to identify and evaluate SQL with different execution plans](https://rammpeter.blogspot.com/2016/04/panorama-how-to-identify-and-evaluate.html)
13. 2016-06-03 – [Panorama: How to analyze blocking locks in Oracle-DB](https://rammpeter.blogspot.com/2016/06/panorama-how-to-analyze-blocking-locks.html)
14. **2016-08-17 – [Generate recommendation lists for index compression on Oracle-DB](https://rammpeter.blogspot.com/2016/08/generate-recommendation-lists-for-index.html)**
15. 2016-11-16 – [Panorama: Save request parameter to recall page with specific filters at later time](https://rammpeter.blogspot.com/2016/11/panorama-save-request-parameter-to.html)
16. **2016-11-25 – [Clarify myths of indexing foreign key constraints on Oracle-DB](https://rammpeter.blogspot.com/2016/11/clarify-myths-of-indexing-foreign-key.html)**
17. 2016-12-06 – [Don’t flood Oracle-DB’s result cache](https://rammpeter.blogspot.com/2016/12/dont-flood-oracle-dbs-result-cache.html)
18. 2016-12-09 – [Analyze pluggable database with Panorama](https://rammpeter.blogspot.com/2016/12/analyze-pluggable-database-with-panorama.html)
19. 2017-01-29 – [Panorama is available now as Docker image](https://rammpeter.blogspot.com/2017/01/panorama-is-available-now-as-docker.html)
20. 2017-02-25 – [Common Oracle DB pitfall: too few redo log groups](https://rammpeter.blogspot.com/2017/02/common-oracle-db-pitfall-too-less-redo.html)
21. 2017-03-22 – [Oracle-DB: Identify excessive logon/logoff operations with short-running sessions](https://rammpeter.blogspot.com/2017/03/how-to-identify-excessive-logonlogoff.html)
22. 2017-04-14 – [Oracle-DB: Does Active Session History always allows you to reconstruct your active sessions behaviour?](https://rammpeter.blogspot.com/2017/04/oracle-db-does-active-session-history.html)
23. 2017-06-12 – [Common pitfalls using SQL*Net via Firewalls](https://rammpeter.blogspot.com/2017/06/common-pitfalls-using-sqlnet-via.html)
24. 2017-06-14 – [Panorama: Explore free space fragmentation of tablespaces](https://rammpeter.blogspot.com/2017/06/panorama-explore-free-space.html)
25. 2017-09-11 – [Scan Oracle-DB for excessive execution of SQL with literals instead of bind variables](https://rammpeter.blogspot.com/2017/09/panorama-scan-your-system-for-excessive.html)
26. 2017-09-13 – [Oracle-DB: Use "SQL Translation Framework" to quickly fix problems with SQLs](https://rammpeter.blogspot.com/2017/09/panorama-use-sql-translation-framework.html)
27. **2017-10-12 – [Oracle-DB: Identify unused indexes](https://rammpeter.blogspot.com/2017/10/oracle-db-identify-unused-indexes.html)**
28. 2017-11-16 – [Oracle-DB: How to check for appropriate sequence caching](https://rammpeter.blogspot.com/2017/11/oracle-db-how-to-check-for-appropriate.html)
29. 2017-11-17 – [Oracle-DB: AWR and ASH for Standard Edition / without Diagnostics Pack](https://rammpeter.blogspot.com/2017/11/oracle-db-awr-and-ash-without.html)
30. 2017-12-01 – [Panorama: Do I need Diagnostics Pack and Tuning Pack license  to use Panorama?](https://rammpeter.blogspot.com/2017/12/panorama-do-i-need-diagnostics-pack-and.html)
31. 2018-01-14 – [Panorama: Handle SQL patches for Oracle-DB](https://rammpeter.blogspot.com/2018/01/panorama-handle-sql-patches-for-oracle.html)
32. 2018-03-19 – [Oracle-DB: Evaluation of recorded SQL-Monitor reports with Panorama](https://rammpeter.blogspot.com/2018/03/oracle-db-evaluation-of-recorded-sql.html)
33. 2018-09-05 – [Panorama: Evaluate SGA memory usage and resize operations for Oracle DBs](https://rammpeter.blogspot.com/2018/09/panorama-evaluate-sga-memory-usage-and.html)
34. 2018-09-19 – [Oracle-DB: OLTP-Compression - what's true and what's wrong](https://rammpeter.blogspot.com/2018/09/oracle-db-oltp-compression-whats-true.html)
35. 2019-02-08 – [Panorama: Oracle-DB's Performance-Hub report now integrated](https://rammpeter.blogspot.com/2019/02/panorama-oracle-dbs-performance-hub.html)
36. 2019-03-27 – [Panorama: Configure https access to Docker container with Nginx](https://rammpeter.blogspot.com/2019/03/panorama-configure-https-access-to.html)
37. 2019-03-28 – [Panorama: Show history of Dynamic Remastering in Oracle RAC-cluster](https://rammpeter.blogspot.com/2019/03/panorama-show-history-of-dynamic.html)
38. 2019-08-08 – [Panorama: Determining candidates for storage reorganization in Oracle-DB](https://rammpeter.blogspot.com/2019/08/panorama-determining-candidates-for.html)
39. 2019-09-03 – [Panorama: List Oracle trace files and it's content](https://rammpeter.blogspot.com/2019/09/panorama-list-oracle-trace-files-and.html)
40. 2019-09-20 – [Using Panorama for autonomous database in Oracle cloud](https://rammpeter.blogspot.com/2019/09/using-panorama-for-autonomous-database.html)
41. 2019-11-10 – [Oracle-DB: List tables suitable for partition exchange](https://rammpeter.blogspot.com/2019/11/oracle-db-list-tables-suitable-for.html)
42. **2019-12-27 – [Oracle-DB: Identify non-relevant indexes for secure deletion](https://rammpeter.blogspot.com/2019/12/oracle-db-identification-of-non.html)**
43. 2020-03-18 – [Oracle-DB: Taking fragmentation into account when calculating the free tablespace](https://rammpeter.blogspot.com/2020/03/oracle-db-taking-fragmentation-into.html)
44. 2020-10-06 – [Oracle-DB: Retrospective analysis of blocking locks with Panorama](https://rammpeter.blogspot.com/2020/10/oracle-db-retrospective-analysis-of.html)
45. 2020-10-12 – [Oracle-DB: Cost of dedicated DB session connect/disconnect](https://rammpeter.blogspot.com/2020/10/oracle-db-cost-of-session.html)
46. 2021-01-05 – [Oracle-DB: Link between audit trail and active session history](https://rammpeter.blogspot.com/2021/01/oracle-db-link-between-audit-trail-and.html)
47. 2021-05-29 – [Oracle-DB: Run a rolling window over interval partitioned tables / avoid ORA-14300, ORA-14758](https://rammpeter.blogspot.com/2021/05/oracle-db-run-rolling-window-over.html)
48. 2021-06-12 – [Oracle-DB: Real-time monitoring dashboard in Panorama](https://rammpeter.blogspot.com/2021/06/oracle-db-real-time-monitoring.html)
49. 2022-06-10 – [Panorama: Long-term trend analysis of Oracle database workload](https://rammpeter.blogspot.com/2019/02/panorama-long-term-trend-analysis-of.html)
50. **2023-03-27 – [Oracle-DB: Requirements for a multi-column index for protecting foreign key constraints](https://rammpeter.blogspot.com/2023/03/oracle-db-requirements-for-multi-column.html)**
51. 2023-06-07 – [Oracle-DB: How to enforce the optimizer to do group operations at the most inner level](https://rammpeter.blogspot.com/2023/06/oracle-db-how-to-enforce-optimizer-to.html)
52. 2023-08-15 – [Oracle-DB: Ensure uniqueness across table boundaries](https://rammpeter.blogspot.com/2023/08/oracle-db-ensure-uniqueness-across.html)
53. 2023-09-21 – [Oracle DB: Evaluate database audit trail with Panorama](https://rammpeter.blogspot.com/2023/09/oracle-db-evaluate-database-audit-trail.html)
54. 2023-12-07 – [Oracle-DB: How to evaluate the "hint_usage" section of column OTHER_XML in execution plan](https://rammpeter.blogspot.com/2023/12/oracle-db-how-to-evaluate-hintusage.html)
55. 2023-12-19 – [Oracle-DB: Find SQLs that are missing partition pruning even if it could be possibly used](https://rammpeter.blogspot.com/2023/12/oracle-db-find-sqls-that-are-missing.html)
56. 2023-12-20 – [Oracle-DB: Get the benefits of Access_Predicates and Filter_Predicates in AWR starting with 19.19](https://rammpeter.blogspot.com/2023/12/oracle-db-get-benefits-of.html)
57. 2024-02-01 – [Oracle-DB: Find SQLs where expected parallel DML or direct load does not work](https://rammpeter.blogspot.com/2024/02/oracle-db-find-sqls-where-expected.html)
58. 2024-03-25 – [Oracle-DB: Monitor gradual password rollover usage](https://rammpeter.blogspot.com/2024/03/oracle-db-monitor-gradual-password.html)
59. **2024-08-15 – [Oracle-DB: Apparent cardinality problem with expressions indexed by a function based index](https://rammpeter.blogspot.com/2024/08/oracle-db-cardinality-problem-for.html)**
60. 2024-08-20 – [Oracle-DB: Speedup parallel HASH JOIN BUFFERED by using HASH JOIN SHARED](https://rammpeter.blogspot.com/2024/08/oracle-db-speedup-parallel-hash-join.html)
61. 2024-09-29 – [Oracle DB: Evaluate current segment statistics prior to next AWR snapshot](https://rammpeter.blogspot.com/2024/09/oracle-db-evaluate-current-segment.html)
62. 2024-12-06 – [Oracle DB: Detect missing use of prepared statements in SQLs](https://rammpeter.blogspot.com/2024/12/oracle-db-detect-missing-use-of.html)
63. 2025-01-17 – [Oracle-DB: Accessing Unified_Audit_Trail is very slow. Why?](https://rammpeter.blogspot.com/2025/01/oracle-db-accessing-unifiedaudittrail.html)
64. 2025-01-23 – [Oracle-DB: Estimate network latency of client connections by evaluation of Active Session History](https://rammpeter.blogspot.com/2025/01/oracle-db-estimate-network-latency-of.html)
65. 2025-01-28 – [Oracle-DB: Cleanup Unified Audit Trail with dynamic number of rows and oldest timestamp, but limited storage size](https://rammpeter.blogspot.com/2025/01/oracle-db-cleanup-unified-audit-trail.html)
66. 2025-04-01 – [Oracle-DB: Valid and enabled LOGON trigger does not fire at Exadata Cloud Service](https://rammpeter.blogspot.com/2025/04/oracle-db-valid-and-enabled-logon.html)
67. 2025-08-07 – [Oracle-DB: New SQL Diagnostic Report in rel. 19.28](https://rammpeter.blogspot.com/2025/08/oracle-db-new-sql-diagnostics-report-in.html)
68. 2025-11-04 – [Oracle-DB: Run TPC benchmark with hammerdb on Standard Edition](https://rammpeter.blogspot.com/2025/11/oracle-db-run-tpc-benchmark-with.html)
69. 2026-01-14 – [Oracle-DB: Check user-defined PL/SQL functions for missing DETERMINISTIC flag](https://rammpeter.blogspot.com/2026/01/oracle-db-check-user-defined-plsql.html)
70. 2026-03-31 – [Oracle-DB: Create trace file for optimizer parse (event 10053)](https://rammpeter.blogspot.com/2026/03/oracle-db-create-trace-file-for.html)
71. **2026-06-03 – [Oracle-DB: Find problematic iteration at skipped columns for INDEX RANGE SCAN with multi-column indexes](https://rammpeter.blogspot.com/2026/06/oracle-find-problematic-iteration-at-skipped-index-columns.html)**
72. 2026-06-29 – [Oracle-DB: Retrieving extended statistics in execution plan for a specific SQL only](https://rammpeter.blogspot.com/2026/06/oracle-db-retrieving-extended.html)
73. **2026-07-02 – [Oracle-DB: Check if an index is used in SQL Plan Management directives or optimizer hints](https://rammpeter.blogspot.com/2026/07/oracle-db-check-if-index-in-used-in-sql.html)**
74. 2026-09-16 – [Oracle DB: Show long running operations from GV$Session_LongOps including the name of the accessed partitions](https://rammpeter.blogspot.com/2026/09/oracle-db-show-long-running-operations.html)

## Open questions

- Several posts refer to **screenshots** that the feed did not capture. The
  Panorama how-tos and the execution plan posts in particular carry part of their
  message through images; the wiki is missing part of the evidence there.
- The post of 2024-12-06 refers to another location of the author's outside the
  blog: <https://rammpeter.github.io/oracle_performance_tuning.html> with
  ready-made selections. Not yet ingested.
- Several posts end with a question to the readers (e.g. 2016-11-25, 2018-09-19,
  2020-10-06, 2023-08-15, 2024-12-06). Whether there were any answers is not
  apparent from the feed — comments are not included in it.

## Source files

All posts are archived in `raw/posts/` (fetched on 2026-10-01); see
`raw/posts/README.md`. Seven files were rewritten on 2026-10-01 after an
extraction defect, see `log.md`.

## Sources

- [Blog series on indexing](../sources/blog-indexing.md)
- [Blog series on execution plans and the optimizer](../sources/blog-execution-plans.md)
- [Blog series on bind variables and SQL text](../sources/blog-bind-variables.md)
- [Blog series on locks and serialisation](../sources/blog-locks.md)
- [Blog series on sessions, connections and the network](../sources/blog-sessions-and-connections.md)
- [Blog series on system load and monitoring](../sources/blog-system-load.md)
- [Blog series on the audit trail](../sources/blog-audit-trail.md)
- [Blog series on storage, tablespaces and redo](../sources/blog-storage.md)
- [Blog series on partitioning and parallel processing](../sources/blog-partitioning.md)
- [Blog series on caching and PL/SQL](../sources/blog-caching-and-plsql.md)
- [Blog series on Panorama as a tool](../sources/blog-panorama-the-tool.md)
