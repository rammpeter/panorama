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
<https://speakerdeck.com/rammpeter>. Next to [[rammpeter-blog]] they are the
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
| 2016-05 | Active Session History: into the deep | DOAG Database | de | 16 | [[talks-ash-and-temp]] |
| 2017-05 | Root-Cause-Analyse nach "unable to extent temp segment" | DOAG | de | 14 | [[talks-ash-and-temp]] |
| 2018-04 | Beeinflussen der Ausführungspläne von SQL-Statements ohne Code-Anpassung | "ACC" | de | 17 | [[talks-sql-plan-management]] |
| 2018-11 | Systematische Rasterfahndung nach Performance-Antipattern | DOAG Dresden | de | 19 | [[talks-dragnet-and-proactive-tuning]] |
| 2020-12 | Sicheres Identifizieren von nicht relevanten Indizes | — | de | 30 | [[talks-indexes]] |
| 2022-05 | MOVEX Change Data Capture | DOAG Database | en | 25 | [[talks-jarbler-and-movex-cdc]] |
| 2022-12 | Panorama-Sampler: AWR und ASH lizenzfrei für alle Editionen | — | de | 19 | [[talks-panorama-and-sampler]] |
| 2023-10 | Effiziente Nutzung von function-based Indexes | DOAG Regio | de | 12 | [[talks-indexes]] |
| 2023-11 | Efficient use of function-based indexes | — | en | 11 | [[talks-indexes]] |
| 2024-01 | Oracle Database Performance Analysis with Panorama | ODTUG | en | 45 | [[talks-panorama-and-sampler]] |
| 2024-02 | Oracle Advanced Compression – Erfahrungen aus dem praktischen Einsatz | IT-Tage | de | 37 | [[talks-advanced-compression]] |
| 2025-05 | Jarbler: Run a Ruby application as Java jar file | — | en | 7 | [[talks-jarbler-and-movex-cdc]] |
| 2025-11 | Alternative to AWR and ASH, license-free for Oracle DB Standard Edition | — | en | 20 | [[talks-panorama-and-sampler]] |
| 2026-05 | DB Performance Tuning: Firefighting or Fixing Root Causes? | DOAG Datenbank | en | 26 | [[talks-dragnet-and-proactive-tuning]] |

Dates are those on the title slides. Venues are taken from the file names; a
dash means the file name gives none. Several older decks were uploaded to
Speakerdeck only in 2023–2024; the decks before that point to SlideShare
(<https://www.slideshare.net/PeterRamm1>).

## What the talks add to the blog

- **A frame for the whole subject**: the eight factors that influence database
  performance, and the choice between reactive and proactive tuning
  → [[proactive-performance-tuning]].
- **Side-by-side comparisons**: [[sql-plan-management]] (four techniques with
  licences), [[advanced-compression]] (all table, index and LOB methods with
  measurements).
- **A technique the blog only touches**: [[function-based-indexes]] as a way to
  shrink an index by orders of magnitude.
- **The inside of the sampler**: limits, RAC and PDB rules, architecture
  → [[panorama-sampler]], [[panorama-sampler-internals]].
- **The author's own statement of purpose** for [[panorama]].

## About the author, as stated on the slides

Peter Ramm: team lead for strategic-technical consulting, later software
architect and team lead, at Otto Group Solution Provider (OSP) Dresden, a
subsidiary of the Otto Group founded in 1991; the company became part of "Otto
Group one.O" in 2025. Focus: development of OLTP systems on Oracle, from
architecture consulting to troubleshooting, performance optimisation of existing
systems. "More than 35 years of experience in IT projects" (2026). Oracle ACE
Associate since 2024 (2026 deck).

## Relationships

- The other body of material: [[rammpeter-blog]]. Several talks are the stage
  version of a blog post and link to it.
- The tool nearly all of them demonstrate: [[panorama]].
- Two further tools by the author: [[jarbler]], [[movex-cdc]].

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

- [[talks-ash-and-temp]]
- [[talks-sql-plan-management]]
- [[talks-dragnet-and-proactive-tuning]]
- [[talks-indexes]]
- [[talks-panorama-and-sampler]]
- [[talks-advanced-compression]]
- [[talks-jarbler-and-movex-cdc]]
