---
title: Panorama Sampler
type: entity
subtype: component
status: draft
tags: [panorama, licensing]
created: 2026-10-01
updated: 2026-10-02
sources: [blog.md, posts/]
---

# Panorama Sampler

Panorama's own facility for recording session activity and historical performance
data — the substitute wherever [[awr]] and [[ash]] may not be used for licensing
reasons.

## Summary

The clearest statement about it comes from [[blog-locks]] (2020-10-06):

> "Precondition for using ASH is the Enterprise Edition of Oracle DB and the
> licensing of the Diagnostics Pack. If you don't have licensed Diagnostics Pack
> or you are running Standard or Express Edition, then you can use the similar
> function of Panorama-Sampler to record the session activity. **Panorama
> evaluates both sources (AWR/ASH or Panorama-Sampler) transparently in the same
> way.**"

The last sentence is the decisive one: the evaluations are **the same**. The
sampler is not a stripped-down side feature but an interchangeable data source —
the retrospective lock analysis from [[blocking-locks]] works with it just as it
does with ASH.

Affected are therefore Standard Edition, Express Edition and any Enterprise
Edition without the Diagnostics Pack ([[blog-indexing]], 2019-12-27 names the
same purpose).

## What it records beyond AWR

([[blog-panorama-the-tool]], 2017-11-17) In addition to Oracle's AWR, the sampler
can also record historical information for:

- the size evolution of tablespace objects
- the occupancy of the DB cache by objects
- detailed information about blocking lock scenarios

> None of these is part of the AWR recordings. The sampler is therefore not only
> a licence-free replacement but in these three respects a genuine addition —
> see [[sga-memory-management]] for the DB cache case.

It also feeds the condensed long-term data → [[long-term-trend-analysis]].

## Relationships

- A component of [[panorama]].
- Takes the place of [[awr]] and [[ash]] → [[management-pack-licensing]].
- Underpins [[blocking-locks]], [[long-term-trend-analysis]] and the
  dashboard described in [[panorama]].

## Open questions

- How does the sampler work technically — sampling interval, storage location,
  retention period?
- Where are its limits compared with real ASH? "Similar function" and
  "transparently in the same way" leave open which evaluations are *not*
  possible. [[management-pack-licensing]] records the hard edge: access to AWR
  tables for which no comparable sampler data exists fails even when sampler mode
  is selected.

## Sources

- [[blog-locks]]
- [[blog-panorama-the-tool]]
- [[blog-indexing]]
