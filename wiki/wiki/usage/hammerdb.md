---
title: HammerDB
type: entity
subtype: external
status: draft
tags: [benchmark, tool]
created: 2026-10-01
updated: 2026-10-02
sources: [blog.md, posts/]
---

# HammerDB

A free tool for database benchmarks (<https://www.hammerdb.com>), also available
as a Docker image. In the blog, the means of choice for producing synthetic load
in the first place, which can then be analysed.

## The occasion

([Blog series on Panorama as a tool](../sources/blog-panorama-the-tool.md), 2025-11-04) For a small demo the author needed
synthetic load on an Oracle database — specifically a TPC-C benchmark on an
**SE2** instance under Oracle Linux.

> The circumstance is telling: the whole blog is about *analysing* load. This
> post solves the prior question of how to obtain load at all without a
> production system — and on a Standard Edition at that.

## The procedure

Three TCL scripts, passed into the container via a mounted directory:

- **`config.tcl`** — database (`dbset db ora`), benchmark (`dbset bm TPC-C`), DBA
  access, connect string (the IP of the Docker host, not `localhost`), the number
  of warehouses as a scaling factor, the number of virtual users, schema and
  tablespace.
- **`build.tcl`** — loads the configuration and calls `buildschema`.
- **`run.tcl`** — the run itself, with a ramp-up time (not counted in the result)
  and a measurement duration.

**One detail with a licensing angle:** `diset tpcc ora_driver test` selects the
driver **without** AWR snapshots. The alternative `timed` creates AWR snapshots —
that only works in the Enterprise Edition and touches
[Management pack licensing](management-pack-licensing.md).

## An open loose end

The author explicitly names what does **not** work for him: running it from the
command line — as a cron job, say — fails because the Oracle client library is
then reported as non-existent:

```
Oratcl_Init(): Failed to load /home/instantclient_21_18/libclntsh.so with error
libnnz21.so: cannot open shared object file: No such file or directory
```

His workaround: start the container as a daemon, connect into it and run a loop
script in the background via `nohup` that executes the benchmark repeatedly until
the container stops.

> Explicitly labelled as a "quick workaround", not as a recommendation.

## Relationships

- Produces the load that is then evaluated with [Panorama](panorama.md), [ASH](ash.md) and
  [Measuring system load](measuring-system-load.md).
- The driver choice touches [Management pack licensing](management-pack-licensing.md).
- Operated via Docker, like [Panorama operations](panorama-operations.md).

## Open questions

- The cause of the library problem is unresolved — is `libnnz21.so` missing from
  the image, or is an environment path not set on a non-interactive start?
- Which metrics does the run deliver, and how comparable are they between
  configurations? The post describes the setup, not the evaluation.

## Sources

- [Blog series on Panorama as a tool](../sources/blog-panorama-the-tool.md)
