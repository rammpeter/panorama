---
title: Talk on influencing execution plans without code changes
type: source
status: maintained
tags: [execution-plan, optimizer, licensing]
created: 2026-10-04
updated: 2026-10-04
sources: [speakerdeck.md, speakerdeck/2018-04_ACC-Panorama-SQL-Plan-Management.pdf]
---

# Talk on influencing execution plans without code changes

One German deck from [[rammpeter-talks]], April 2018: "Oracle-DB: Beeinflussen
der Ausführungspläne von SQL-Statements ohne Code-Anpassung — Verschiedene
Verfahren und ihre Unterstützung durch Panorama". 17 slides, file
`raw/speakerdeck/2018-04_ACC-Panorama-SQL-Plan-Management.pdf`. The file name
carries the venue abbreviation "ACC", which the slides do not explain.

It is the only source in the wiki that puts all four techniques side by side.

## Key points

**The motivation** (slide 4). Fixing a problematic SQL normally means rolling
out changed software. In a critical production situation that is too slow; the
database offers ways to intervene ad hoc.

**Four techniques in one table** (slide 5):

| Technique | Effect | Licence |
|---|---|---|
| SQL plan baseline | prescribes the plan hash value to use | EE (plus Tuning Pack for creating it from AWR data, as Panorama's snippet does) |
| SQL profile | injects optimizer hints | EE + Diagnostics and Tuning Pack |
| SQL patch | injects optimizer hints, like a profile | none — Standard Edition too |
| SQL translation | replaces the whole SQL text | EE |

→ [[sql-plan-management]], [[sql-translation-framework]].

**A baseline does not store a plan** (slide 7). It prescribes the *plan hash
value*; the optimizer must itself be able to arrive at a plan with that hash.

**The practical value of the baseline route** (slide 7): when a plan has turned
bad, a better one is found by comparing executions in the AWR history, and the
problem is "fixed in minutes without having understood the SQL at all".

**Panorama deliberately does not generate SQL profiles** (slide 9): the SQL
patch achieves the same without the edition and pack restrictions.

**Hints in a patch need the query block** (slide 11): for complex statements the
hint must name the query block, as in `INDEX(@SEL$1 h@SEL$1, IDX_Hugo_Neu)`.

**A translation script has three parts** (slide 13): SYSDBA grants the user the
right to create translation profiles; the user creates the profile with old and
new text; SYSDBA creates a logon trigger that activates the translation in the
user's sessions → [[sql-translation-framework]], [[logon-trigger]].

**All four are quick fixes** (slide 14). The binding rests on SQL ID or SQL
text and is lost when the statement changes. They should bridge the time until
the next rollout, not replace it.

**Why Panorama shows them in red** (slide 14): without the information that a
directive exists, there is "the risk of confusion about how the optimizer arrives
at the plan actually used". The menu "SGA/PGA details" / "SQL plan management"
lists all existing directives *including whether they are really used*.

## Impact on the wiki

- [[sql-plan-management]] — the licence table refined, the plan-hash point, the
  reason for not supporting profiles, the query block hint, the quick-fix
  framing.
- [[sql-translation-framework]] — licence and the three-part script.
- [[management-pack-licensing]] — the refined licence rows.

## Changes over time and disagreements

- **Licence of the baseline.** [[sql-plan-management]] recorded from the blog
  simply "additional licence needed: yes" for baselines. The deck is more
  precise: the baseline itself needs Enterprise Edition; the *Tuning Pack* is
  needed for creating it from AWR through a SQL tuning set, which is the route
  Panorama generates. A refinement, not a contradiction.
- **SQL patch API.** The deck of 2018-04 shows
  `sys.DBMS_SQLDiag_Internal.i_create_patch` and mentions that the generator
  handles the differing API per release, matching the blog
  ([[blog-execution-plans]], 2018-01-14).
- The deck names internally hosted Panorama instances reachable under
  `…:8080/Panorama` — the path layout discussed in [[panorama-operations]].

## Open questions

- Does the SQL translation framework really require Enterprise Edition? The deck
  says so; the blog post on it does not state a licence.
- What does "ACC" stand for?

## Source files

`raw/speakerdeck.md` (pointer); PDF downloaded on 2026-10-03 into
`raw/speakerdeck/`.
