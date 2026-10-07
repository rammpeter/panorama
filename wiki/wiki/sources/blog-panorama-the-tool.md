---
title: Blog series on Panorama as a tool
type: source
status: maintained
tags: [panorama, licensing, operations]
created: 2026-10-01
updated: 2026-10-02
sources: [blog.md, posts/]
---

# Blog series on Panorama as a tool

Fourteen posts from [rammpeter.blogspot.com](../usage/rammpeter-blog.md) between 2016 and 2025 about the tool
itself: operations, licensing model, individual functions — and once a load
generator, to have anything to measure at all.

## The posts

| Date | Title | Focus |
|---|---|---|
| 2016-03-20 | User is enabled to add personal SQL to dragnet list | [Dragnet Investigation](../usage/dragnet.md) |
| 2016-11-16 | Save request parameter to recall page with specific filters at later time | [Panorama](../usage/panorama.md) |
| 2016-12-09 | Analyze pluggable database with Panorama | [Pluggable databases](../usage/pluggable-databases.md) |
| 2017-01-29 | Panorama is available now as Docker image | [Panorama operations](../usage/panorama-operations.md) |
| 2017-11-17 | AWR and ASH for Standard Edition / without Diagnostics Pack | [Panorama Sampler](../usage/panorama-sampler.md) |
| 2017-12-01 | Do I need Diagnostics Pack and Tuning Pack license to use Panorama? | [Management pack licensing](../usage/management-pack-licensing.md) |
| 2018-03-19 | Evaluation of recorded SQL-Monitor reports with Panorama | [SQL Monitor](../usage/sql-monitor.md) |
| 2018-09-05 | Evaluate SGA memory usage and resize operations | [SGA memory management](../usage/sga-memory-management.md) |
| 2019-02-08 | Oracle-DB's Performance-Hub report now integrated | [Panorama](../usage/panorama.md) |
| 2019-03-27 | Configure https access to Docker container with Nginx | [Panorama operations](../usage/panorama-operations.md) |
| 2019-03-28 | Show history of Dynamic Remastering in Oracle RAC-cluster | [Dynamic remastering](../usage/dynamic-remastering.md) |
| 2019-09-03 | List Oracle trace files and it's content | [Panorama](../usage/panorama.md) |
| 2019-09-20 | Using Panorama for autonomous database in Oracle cloud | [Panorama operations](../usage/panorama-operations.md) |
| 2025-11-04 | Run TPC benchmark with hammerdb on Standard Edition | [HammerDB](../usage/hammerdb.md) |

## Key points

**The licensing model is built into the tool, not glued on.** On connecting, the
user has to confirm one of **four** options; the pre-selection follows the init
parameter `control_management_pack_access`. Without confirmation, every function
call that would need AWR data or licence-restricted packages fails
(2017-12-01) → [Management pack licensing](../usage/management-pack-licensing.md).

**The sampler can do more than AWR.** It additionally records the size evolution
of tablespace objects, the occupancy of the DB cache by objects and detailed
information about blocking lock scenarios — none of which is part of the AWR
recordings (2017-11-17) → [Panorama Sampler](../usage/panorama-sampler.md).

**SQL Monitor requires the Tuning Pack**, not the Diagnostics Pack — the only
Panorama function with that prerequisite (2017-12-01, 2018-03-19)
→ [SQL Monitor](../usage/sql-monitor.md).

**Automatic SGA management can drift into a skew.** Missing bind variables let
the shared pool grow and the buffer cache shrink; with alternating load patterns
`ORA-04031` threatens as well if resize operations do not take effect fast
enough. The remedy: **minimum values** per component (2018-09-05)
→ [SGA memory management](../usage/sga-memory-management.md).

**CDB and DBA views show different things depending on where you are
connected.** The post of 2016-12-09 presents this as a matrix — notably the
combination "as a user in the CDB via `DBA_xx`" yields only the root CDB
→ [Pluggable databases](../usage/pluggable-databases.md).

**From 12.2 trace files can be read via SQL.** That enables developers without
file system access to inspect the trace files they produce themselves
(2019-09-03) → [Panorama](../usage/panorama.md).

## Notes on the evidence

**Two cases of obsolete technology.** The SQL Monitor report (2018-03-19) and the
Performance Hub (2019-02-08) both require **Adobe Flash**; the SQL Monitor post
already contains a hint back then that Chrome often rejects Oracle's Flash source
URLs. Flash has been discontinued since the end of 2020 — these descriptions are
therefore historical.

**An incomplete solution, openly named.** In the HammerDB post (2025-11-04) the
author concedes that running it from the command line — that is, as a cron job —
has **not** worked for him so far: the Oracle client library is then reported as
non-existent. He shows the error message and puts a workaround next to it instead
of concealing the problem.

**A topic with thin sources.** On dynamic remastering the author notes: *"has
very little official documentation"*, and refers to three external blogs. The
wiki page carries that uncertainty with it.

## Source files

`raw/posts/10-*`, `15-*`, `18-*`, `19-*`, `29-*`, `30-*`, `32-*`, `33-*`,
`35-*`, `36-*`, `37-*`, `39-*`, `40-*`, `68-*`
