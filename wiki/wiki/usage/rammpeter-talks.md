---
title: Talks and slide decks by Peter Ramm
type: entity
subtype: event
status: draft
tags: [source, panorama, oracle]
created: 2026-10-04
updated: 2026-10-04
sources: [speakerdeck.md, speakerdeck/]
---

# Talks and slide decks by Peter Ramm

The conference talks of Panorama's author, published as slide decks at
<https://speakerdeck.com/rammpeter>. Next to [rammpeter.blogspot.com](rammpeter-blog.md) they are the
second body of his own material in this wiki.

## Summary

Fourteen decks from 2016 to 2026, eight in German and six in English. Where the
blog documents single findings, the talks *arrange* them: several decks are the
only place where related techniques stand side by side (the four ways to
influence a plan, all compression methods, the four roles of an index as a
procedure). Most were given at DOAG events.

The talks are summarised in seven source pages, grouped by topic.

## The decks

| Date | Title | Venue | Lang. | Slides | Summarised in |
|---|---|---|---|---|---|
| 2016-05 | Active Session History: into the deep | DOAG Database | de | 16 | [Talks on Active Session History and TEMP analysis](../sources/talks-ash-and-temp.md) |
| 2017-05 | Root-Cause-Analyse nach "unable to extent temp segment" | DOAG | de | 14 | [Talks on Active Session History and TEMP analysis](../sources/talks-ash-and-temp.md) |
| 2018-04 | Beeinflussen der Ausführungspläne von SQL-Statements ohne Code-Anpassung | "ACC" | de | 17 | [Talk on influencing execution plans without code changes](../sources/talks-sql-plan-management.md) |
| 2018-11 | Systematische Rasterfahndung nach Performance-Antipattern | DOAG Dresden | de | 19 | [Talks on dragnet investigation and proactive tuning](../sources/talks-dragnet-and-proactive-tuning.md) |
| 2020-12 | Sicheres Identifizieren von nicht relevanten Indizes | — | de | 30 | [Talks on indexes](../sources/talks-indexes.md) |
| 2022-05 | MOVEX Change Data Capture | DOAG Database | en | 25 | [Talks on Jarbler and MOVEX CDC](../sources/talks-jarbler-and-movex-cdc.md) |
| 2022-12 | Panorama-Sampler: AWR und ASH lizenzfrei für alle Editionen | — | de | 19 | [Talks on Panorama and the Panorama Sampler](../sources/talks-panorama-and-sampler.md) |
| 2023-10 | Effiziente Nutzung von function-based Indexes | DOAG Regio | de | 12 | [Talks on indexes](../sources/talks-indexes.md) |
| 2023-11 | Efficient use of function-based indexes | — | en | 11 | [Talks on indexes](../sources/talks-indexes.md) |
| 2024-01 | Oracle Database Performance Analysis with Panorama | ODTUG | en | 45 | [Talks on Panorama and the Panorama Sampler](../sources/talks-panorama-and-sampler.md) |
| 2024-02 | Oracle Advanced Compression – Erfahrungen aus dem praktischen Einsatz | IT-Tage | de | 37 | [Talk on Oracle Advanced Compression in practice](../sources/talks-advanced-compression.md) |
| 2025-05 | Jarbler: Run a Ruby application as Java jar file | — | en | 7 | [Talks on Jarbler and MOVEX CDC](../sources/talks-jarbler-and-movex-cdc.md) |
| 2025-11 | Alternative to AWR and ASH, license-free for Oracle DB Standard Edition | — | en | 20 | [Talks on Panorama and the Panorama Sampler](../sources/talks-panorama-and-sampler.md) |
| 2026-05 | DB Performance Tuning: Firefighting or Fixing Root Causes? | DOAG Datenbank | en | 26 | [Talks on dragnet investigation and proactive tuning](../sources/talks-dragnet-and-proactive-tuning.md) |

Dates are those on the title slides. Venues are taken from the file names; a
dash means the file name gives none. Several older decks were uploaded to
Speakerdeck only in 2023–2024; the decks before that point to SlideShare
(<https://www.slideshare.net/PeterRamm1>).

## What the talks add to the blog

- **A frame for the whole subject**: the eight factors that influence database
  performance, and the choice between reactive and proactive tuning
  → [Proactive performance tuning](proactive-performance-tuning.md).
- **Side-by-side comparisons**: [SQL plan management](sql-plan-management.md) (four techniques with
  licences), [Table, index and LOB compression compared](advanced-compression.md) (all table, index and LOB methods with
  measurements).
- **A technique the blog only touches**: [Function-based indexes](function-based-indexes.md) as a way to
  shrink an index by orders of magnitude.
- **The inside of the sampler**: limits, RAC and PDB rules, architecture
  → [Panorama Sampler](panorama-sampler.md), [Panorama Sampler internals](../development/panorama-sampler-internals.md).
- **The author's own statement of purpose** for [Panorama](panorama.md).

## About the author, as stated on the slides

Peter Ramm: team lead for strategic-technical consulting, later software
architect and team lead, at Otto Group Solution Provider (OSP) Dresden, a
subsidiary of the Otto Group founded in 1991; the company became part of "Otto
Group one.O" in 2025. Focus: development of OLTP systems on Oracle, from
architecture consulting to troubleshooting, performance optimisation of existing
systems. "More than 35 years of experience in IT projects" (2026). Oracle ACE
Associate since 2024 (2026 deck).

## Relationships

- The other body of material: [rammpeter.blogspot.com](rammpeter-blog.md). Several talks are the stage
  version of a blog post and link to it.
- The tool nearly all of them demonstrate: [Panorama](panorama.md).
- Two further tools by the author: [Jarbler](../development/jarbler.md), [MOVEX CDC](movex-cdc.md).

## Open questions

- Were the talks recorded? The slides alone carry no speaker notes; screenshots
  on many slides are not described in the text.
- Are there talks that were never uploaded? The decks mention SlideShare as an
  older location, which was not ingested.
- Venue and exact date are unknown for five decks.

## Source files

- `raw/speakerdeck.md` — the pointer
- `raw/speakerdeck/` — the 14 PDFs, downloaded on 2026-10-03 (about 37 MB)

## Sources

- [Talks on Active Session History and TEMP analysis](../sources/talks-ash-and-temp.md)
- [Talk on influencing execution plans without code changes](../sources/talks-sql-plan-management.md)
- [Talks on dragnet investigation and proactive tuning](../sources/talks-dragnet-and-proactive-tuning.md)
- [Talks on indexes](../sources/talks-indexes.md)
- [Talks on Panorama and the Panorama Sampler](../sources/talks-panorama-and-sampler.md)
- [Talk on Oracle Advanced Compression in practice](../sources/talks-advanced-compression.md)
- [Talks on Jarbler and MOVEX CDC](../sources/talks-jarbler-and-movex-cdc.md)
