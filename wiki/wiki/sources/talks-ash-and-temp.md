---
title: Talks on Active Session History and TEMP analysis
type: source
status: maintained
tags: [ash, storage, session]
created: 2026-10-04
updated: 2026-10-04
sources: [speakerdeck.md, speakerdeck/2016-05_DOAG_Database_Active-Session-History_into_the_deep.pdf, speakerdeck/2017-05_DOAG_Root-Cause-Analyse_nach_unable_to_extent_temp_segment.pdf]
---

# Talks on Active Session History and TEMP analysis

Two German slide decks from [[rammpeter-talks]], both given at DOAG events, on
what can be reconstructed from [[ash]] after the fact.

## The decks

| Date | Title | Venue | Slides | File in `raw/speakerdeck/` |
|---|---|---|---|---|
| 2016-05 | Active Session History: into the deep | DOAG Database | 16 | `2016-05_DOAG_Database_Active-Session-History_into_the_deep.pdf` |
| 2017-05 | Root-Cause-Analyse nach "unable to extent temp segment" | DOAG | 14 | `2017-05_DOAG_Root-Cause-Analyse_nach_unable_to_extent_temp_segment.pdf` |

The 2016 deck prints three of Panorama's actual ASH queries in full; the PDF text
of two of them is garbled by letter-spacing and only partly legible.

## Key points

**ASH is "for me the biggest step" in Oracle's analysis functions** (2016,
slide 3). Introduced with 10g, strongly extended in 11g. Every active session is
stored once per second in SGA memory (`V$Active_Session_History`); every tenth
second is persisted with the AWR snapshots (`DBA_Hist_Active_Sess_History`)
→ [[ash]].

**Panorama overlays both ASH sources** (2016, slides 10, 12, 14). Its queries
take the 10-second history from `DBA_Hist_Active_Sess_History` *up to the oldest
sample still in memory* and `UNION ALL` the one-second samples from
`gv$Active_Session_History`. A weight column (`Sample_Cycle` 10 or 1) keeps the
sums comparable. Evaluations therefore reach up to the current second,
independent of the snapshot cycle → [[ash]].

**Without session tagging, pooled sessions cannot be attributed** (2016,
slide 8). With an application server and session pooling, every short
transaction takes an arbitrary session; a process uses a varying number of them.
`DBMS_Application_Info.Set_Module` at the start of a transaction is what makes
the question "why did process XY take three times as long last night?"
answerable at all → [[session-context]].

**The standard workflow** (2016, slide 9): "Session waits" / "Historic", group by
module, show the top ten on a time line, drill down by SQL ID, open the
execution plan, read the "DB time" column to find the plan line that carries the
load.

**Blocking locks in retrospect** (2016, slides 11–12): one row per root blocker,
sorted by the total wait of everything it blocks; the hierarchy is resolved with
`CONNECT BY` over samples rounded to the same instant → [[blocking-locks]].

**ORA-01652: three variants** (2017, slide 4). The session itself allocated the
space; *others* did and this one merely asked last; or unused TEMP is allocated
on another RAC instance (named, not treated further) → [[temp-usage]].

**Where TEMP history comes from** (2017, slide 5). Per session from ASH
(`Temp_Space_Allocated`, every second or ten seconds); per instance from
`DBA_Hist_SysMetric_Summary` / `GV$SysMetric_History` (metric "Temp Space Used")
and from `DBA_Hist_Sysstat`; currently from `GV$SORT_SEGMENT` and
`GV$TEMPSEG_USAGE` → [[temp-usage]].

**The conceptual gap and the workaround** (2017, slides 5–6). A session that
holds TEMP but is inactive, or waiting in class Idle, is not in ASH. The query
therefore takes, for each sample time, the maximum a session showed within
**±20 seconds** ("floating"), so that briefly inactive sessions still count.
This approximates reality; it does not reproduce it → [[temp-usage]].

## Impact on the wiki

- [[ash]] — the overlay of the two sources and the sampling mechanics.
- [[temp-usage]] — the third cause, the data sources, the ±20-second
  approximation.
- [[session-context]] — the pooling argument.
- [[blocking-locks]] — the implementation by `CONNECT BY`.

## Changes over time and disagreements

- The 2017 deck says Panorama "requires Enterprise Edition and Diagnostics Pack
  (so far)". The sampler followed in November 2017
  ([[blog-panorama-the-tool]]).
- The 2016 deck states an AWR default retention of 7 days, as does [[ash]].

## Open questions

- The third ORA-01652 variant — unused TEMP allocated on another RAC instance —
  is only named. How is it recognised and resolved?
- Is the ±20-second window still what Panorama uses, and is it configurable? The
  2017 slide mentions an optional number of seconds in the dialog.

## Source files

`raw/speakerdeck.md` (pointer); PDFs downloaded on 2026-10-03 into
`raw/speakerdeck/`.
