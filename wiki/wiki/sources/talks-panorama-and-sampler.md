---
title: Talks on Panorama and the Panorama Sampler
type: source
status: maintained
tags: [panorama, sampling, licensing]
created: 2026-10-04
updated: 2026-10-04
sources: [speakerdeck.md, speakerdeck/2022-12_Panorama-Sampler.pdf, speakerdeck/2024-01_ODTUG_Performance_Analysis_with_Panorama.pdf, speakerdeck/2025-10_Panorama-Sampler.pdf]
---

# Talks on Panorama and the Panorama Sampler

Three slide decks from [[rammpeter-talks]] that present the tool itself and its
licence-free data source. Together they are the author's own statement of what
[[panorama]] is for and how the [[panorama-sampler]] is built.

## The decks

| Date | Title | Venue / language | Slides | File in `raw/speakerdeck/` |
|---|---|---|---|---|
| 2022-12 | Panorama-Sampler: AWR und ASH lizenzfrei für alle Editionen der Oracle-DB | German | 19 | `2022-12_Panorama-Sampler.pdf` |
| 2024-01 | Oracle Database Performance Analysis with Panorama | ODTUG, English | 45 | `2024-01_ODTUG_Performance_Analysis_with_Panorama.pdf` |
| 2025-11 | Alternative to AWR and ASH, license-free for Oracle DB Standard Edition | English | 20 | `2025-10_Panorama-Sampler.pdf` |

The 2025 deck is an updated English version of the 2022 one; where they differ,
the difference is a change over time and is noted below.

## Key points

**What Panorama is for** (2024, slide 8). The focus is on making complex database
internals usable "without deep insider knowledge", on an analysis *workflow* of
linked steps "as an alternative to a loving collection of individual SQL
scripts", on drilling down from a concrete problem to its root cause, and on
analysis at a distance in time from the incident. It explicitly does **not**
claim to cover all monitoring; functions are added where established tools offer
nothing, too little, or are not accessible to normal users for cost reasons. It
is meant to be used *alongside* tools such as EM Cloud Control → [[panorama]].

**Why a sampler at all** (2022 slide 4, 2025 slide 6). List prices per
processor: Standard Edition 2 17,500 USD, Enterprise Edition 47,500 USD,
Diagnostics Pack 7,500 USD, each plus 22 % support per year. AWR and ASH thus
cost Enterprise Edition *and* the pack; Statspack offers "drastically" less
→ [[management-pack-licensing]].

**The design idea: same structure, different name** (2022 slide 5, 2025
slide 7). The sampler's tables have the same structure as the `DBA_HIST_*` views
of release 19 or 23 and the same name suffix (`PANORAMA_xxx`). That is what lets
Panorama switch data sources, and it lets *other* software use the data too, by
redirecting the AWR view names with synonyms → [[panorama-sampler]],
[[pack-license-filter]].

**How it runs** (2022 slides 7–8, 2025 slides 10 and 12). Recording is done by
PL/SQL in the target database and stored there; nothing is transferred to the
Panorama server. ASH is recorded by a permanent background session. One Panorama
instance can serve any number of databases, each in its own thread. The database
objects are created automatically at first use. The architecture diagram matches
the code read in [[panorama-source-code]] → [[panorama-sampler-internals]].

**What the sampler's ASH cannot do** (2022 slide 9, 2025 slide 13). No plan line
and operation, so load cannot be attributed to lines of the execution plan; only
top-level SQL as in `v$Session.SQL_ID`, so recursive SQL is not reported; no I/O
request and volume figures, because reading `v$SesStat` once per second and
session is too slow → [[panorama-sampler]], [[ash]].

**What it does better** (2022 slide 9). The execution plans it records contain
the access and filter predicates. Oracle's own AWR did not record them up to
release 21, although the columns have existed since 10g.

**RAC and PDB rules** (2022 slide 17, 2025 slide 17). In RAC the sampler records
only the instance it is connected to: one configuration per node, each through a
TNS service bound to that node, all into the same schema. In a CDB, user
`SYSTEM` can sample the CDB and all PDBs with one configuration; any other user
samples only the container it connects to → [[panorama-sampler]].

**A walk through the tool** (2024). Session tagging, ASH drill-down, real-time
dashboard, retrospective lock and TEMP analysis, SQL details and plan stability,
object structure, storage, segment statistics, OS and I/O statistics, SGA and DB
cache, redo logs, dragnet. Most of it confirms pages that already exist from the
blog; new details are noted under *Impact*.

## Impact on the wiki

- [[panorama]] — motivation and differentiation in the author's words; the menu
  table completed; the tip to log every executed SQL.
- [[panorama-sampler]] — the ASH limits, the predicate advantage, the RAC and PDB
  rules, the synonym redirection, the list of replaced AWR views, supported
  releases. Two open questions closed.
- [[panorama-sampler-internals]] — the open question on RAC closed; the data
  sources per domain from the diagram.
- [[management-pack-licensing]] — list prices as the economic background.
- [[redo-logs]], [[sga-memory-management]] — small additions from the 2024 deck.
- New: [[rammpeter-talks]].

## Changes over time and disagreements

- **Supported releases.** 2022: "11.2 to 21, EE, SE, SE2, XE". 2025: "11.2 up to
  26ai". The CI in the repository tests up to 23.5
  ([[panorama-build-test-and-release]]).
- **Packaging.** 2022: "Docker image or self-starting **war** file". 2024 and
  2025: "self-starting **jar** file". The change of packaging falls between the
  two → [[jarbler]].
- **Master password name.** The 2022 deck uses both
  `PANORAMA_MASTER_PASSWORD` (slide 10) and `PANORAMA_SAMPLER_MASTER_PASSWORD`
  (slide 11); the 2025 deck only the former. Consistent with the rename recorded
  in [[panorama-configuration]].
- **"Does not install any objects".** The decks before the sampler say Panorama
  needs no objects of its own; from 2024 the sentence carries the exception
  "except if you're using Panorama-Sampler".
- **AWR default retention** is given as 7 days (2024, slide 14). Kept as stated
  by the source; not checked against Oracle's documentation.

## Open questions

- The decks list the AWR views with a replacement, but not the Panorama functions
  that therefore do *not* work with the sampler.
- No measurements of the sampler's overhead on the sampled database are given.

## Source files

`raw/speakerdeck.md` (pointer to <https://speakerdeck.com/rammpeter>); the PDFs
were downloaded on 2026-10-03 into `raw/speakerdeck/`.
