---
title: Tablespace fragmentation
type: concept
status: draft
tags: [core, storage, oracle]
created: 2026-10-01
updated: 2026-10-02
sources: [blog.md, posts/]
---

# Tablespace fragmentation

> "Even if you think to have enough free space in tablespace your operation may
> end up in: `ORA-01653 unable to extend table … in tablespace …`"
> — [[blog-storage]], 2020-03-18

## Why the total does not count

To create a new extent, the database needs a **contiguous** free chunk the size of
that extent. If enough is free in total but only in smaller slices, the
allocation fails — despite free gigabytes.

Historically this was addressed via `UNIFORM EXTENT SIZE`; today via **locally
managed tablespaces**, which automatically use a limited number of extent sizes.
That reduces the risk but does not eliminate it — particularly not when little is
free in the tablespace anyway.

> An exception from the source ([[blog-storage]], 2017-06-14): anyone using
> `UNIFORM EXTENT SIZE` can skip the topic — the free chunks then cannot be
> smaller than the uniform size.

## The better metric

Instead of checking the total free space: **how many times does the largest
extent in use still fit into it?**

The query from [[blog-storage]] (2020-03-18) joins three sources for this:

- `DBA_DATA_FILES` — current size and, where `AUTOEXTENSIBLE = 'YES'`, the
  extension still possible (`MaxBytes - Bytes`)
- `DBA_EXTENTS` — the largest extent size **in use** per tablespace
- `DBA_FREE_SPACE` — the free chunks, each divided integrally by the largest
  extent size (`TRUNC(f.Bytes / e.Max_Extent_Size)`)

The result is two columns with quite different meanings:

| Column | Meaning |
|---|---|
| `Total_Free_GB` | the total free space — the misleading number |
| `Free_GB_for_largest_Extents` | the space **actually usable** for the largest extent |

Sorting is by the ratio of usable to maximum space — the tablespaces at greatest
risk come first.

## Estimating the next extent size

One residual question remains ([[blog-storage]], 2017-06-14): how large will the
next extent of my object be in the first place? From that follows whether it
still fits. The assumption from the source:

- with allocation type **SYSTEM**: as large as the largest existing extent
- with allocation type **USER**: the configured next extent size of the object

## In Panorama

Fragmentation and remaining space for various extent sizes at one click
([[blog-storage]], 2017-06-14). Menu "Schema/Storage" / "Disk-storage summary"; a
click in the "MB free" column lists available space and extents for several
extent sizes.

## Relationships

- The other side: space that looks occupied but can be released →
  [[storage-reorganisation]].
- The related problem in the TEMP tablespace: [[temp-usage]].
- Also a case where the obvious metric is the wrong one:
  [[bind-variables-and-cursor-sharing]] (SQL area versus buffer cache).

## Open questions

- The query takes the **largest extent in use** as the yardstick. Is that the
  right yardstick for locally managed tablespaces with automatic size selection,
  or does it overstate the risk?
- From what value of `Pct_Free_for_largest_Extents` should you intervene? The
  source supplies the metric without a threshold.

## Sources

- [[blog-storage]]
