# Panorama & Oracle Performance – Log

Chronological, append-only record of what happened when. Every entry starts with
`## [YYYY-MM-DD] <op> | <subject>`, where `<op>` ∈
`setup | ingest | query | lint | maintenance`. Searchable via `grep`:
`grep "^## \[" log.md | tail -5`.

<!-- Append new entries below this line. -->

## [2026-10-01] setup | Panorama & Oracle Performance

Tailored the wiki to its subject.

- **Subject:** Panorama (the tool for performance analysis of Oracle databases)
  together with the Oracle expertise its analyses rest on.
- **Purpose:** memory for ongoing development, reference for everyday analysis,
  source pool for documentation and talks.
- **Audience:** primarily the author of Panorama, occasionally others.
- **Typical sources:** the author's own talks and slides (PDF), blog posts and
  technical articles, personal notes, analysis results and records.
- **Schema change:** replaced the entity subtype `place` with `event`
  (conferences and talks instead of places).

Changed: `CLAUDE.md` (title, the section "What this wiki is about", subtypes),
`index.md` (title, stub entries), `CONFIG.md` (header), `README.md` (title),
`wiki/overview.md` (first overview).
Newly created: `wiki/entities/panorama.md`, `wiki/concepts/awr.md`,
`wiki/concepts/ash.md`, `wiki/concepts/management-pack-licensing.md`
(all `status: stub`).

## [2026-10-01] ingest | Blog rammpeter.blogspot.com – indexing block

Source: `raw/blog.md` contains only a pointer to
<https://rammpeter.blogspot.com> with the instruction to ingest all posts. All 74
posts (2012-05-14 to 2026-09-16) were fetched via the Atom feed and captured;
**only the indexing block was ingested** (8 posts: 2016-08-17, 2016-11-25,
2017-10-12, 2019-12-27, 2023-03-27, 2024-08-15, 2026-06-03, 2026-07-02) — at the
user's request as a pattern first.

Source pages grouped **by topic** at the user's request, not one per post.

New: `wiki/sources/blog-indexing.md`; concepts `indexing`,
`index-usage-monitoring`, `foreign-key-locks`, `index-compression`,
`index-access-paths`, `extended-statistics`; decision
`do-not-blanket-index-foreign-keys` (adopted); entities `rammpeter-blog` (with a
list of all 74 posts), `dragnet`, `panorama-sampler`.

Changed: `wiki/entities/panorama.md` (stub → worked out),
`wiki/concepts/ash.md`, `wiki/concepts/awr.md`,
`wiki/concepts/management-pack-licensing.md` (cross-references each),
`wiki/overview.md`, `index.md`.

Points recorded:
- **Source outside `raw/`.** The authoritative content lives on the web, not as
  an immutable file. Archiving the posts in `raw/` would be needed to satisfy the
  principle. Recorded on `rammpeter-blog` and `blog-indexing`.
- **Revised conclusion** (post 2024-08-15): the author first took the optimizer
  behaviour for a bug, then found the real cause. Only the revised version stands
  as fact in `extended-statistics`; the first assessment is marked superseded.
- **Documentation diverges from observation** (post 2019-12-27):
  `DBA_TAB_MODIFICATIONS` logs only with `MONITORING=YES` according to Oracle's
  documentation up to 19c, but in fact from release 11 also with `NOMONITORING`.
  Recorded in `index-usage-monitoring`.
- **Screenshots missing.** Several posts carry part of their message through
  images that the feed does not supply.

## [2026-10-01] ingest | Blog rammpeter.blogspot.com – remaining 66 posts

The blog is thereby **fully ingested** (74 of 74 posts). The user confirmed the
shape and tone of the pattern block.

**Provenance gap closed:** all 74 posts now sit as individual files in
`raw/posts/` (fetched 2026-10-01 via the Atom feed), plus
`raw/posts/README.md`. The authoritative source is therefore back inside the
wiki. Not archived: the screenshots the feed does not supply.

**Ten new source pages** (grouped by topic, as with the pattern block):
`blog-execution-plans` (9 posts), `blog-bind-variables` (3), `blog-locks` (4),
`blog-sessions-and-connections` (8), `blog-system-load` (7), `blog-audit-trail`
(5), `blog-storage` (6), `blog-partitioning` (5), `blog-caching-and-plsql` (5),
`blog-panorama-the-tool` (14).

**41 new concept pages**, **4 new decision pages** (all `adopted`:
`create-sql-patches-by-sql-text`, `cursor-sharing-force-is-no-substitute`,
`oltp-compression-only-without-updates`,
`declaring-deterministic-deliberately`), **3 new entities**
(`panorama-operations`, `hammerdb`, plus `rammpeter-blog` updated).

**Rewritten:** `wiki/entities/panorama.md` (now with interface patterns and
functional domains), `wiki/concepts/ash.md` (the idle-wait finding),
`wiki/concepts/management-pack-licensing.md` (licence table and the four-option
model), `wiki/entities/panorama-sampler.md`, `wiki/overview.md`, `index.md`
(regenerated from the pages).

Contradictions, revisions and uncertainties recorded:
- **Partly revised decision:** OLTP compression — the 2018 measurements (up to
  95.7 % migrated rows) apply to 11.2–18.0; the author's addendum of 2023-05
  finds "much better, but not deterministic at all" for 19.18. Both states in
  `oltp-compression`, the consequences on the decision page.
- **Apparent contradiction resolved:** `DETERMINISTIC` may be declared
  deliberately falsely according to the post of 2026-01-14, but leads to
  `ORA-08102` according to the post of 2023-08-15. Different contexts; the
  dividing line (function based index yes/no) is a **synthesis of this wiki**,
  not a statement by the author — marked as such in
  `declaring-deterministic-deliberately`.
- **Superseded solution:** the 2021 trick of linking audit trail and ASH via a
  LOGON trigger is replaced for unified auditing by the 2025-02 addendum
  (`AUDIT CONTEXT NAMESPACE USERENV ATTRIBUTES SID`). Both routes in
  `audit-trail`, the older one marked as such.
- **Evolved ranking:** the 2017 search methods for missing bind variables were
  extended in 2024 by the force-matching signature and re-ordered. What is
  recorded is the 2024 version.
- **Contradiction to Oracle's documentation**, in both cases openly named by the
  author: OLTP compression ("I've never seen this really working") and
  `DBA_TAB_MODIFICATIONS` with `NOMONITORING`.
- **Obsolete technology:** the SQL Monitor report and the Performance Hub require
  Adobe Flash (discontinued end of 2020); current state not evidenced.
- **Unresolved problems the author names himself:** no waterproof solution for
  cross-table uniqueness without global serialisation;
  `SQL_TRANSLATION_PROFILE` cannot be set in a running session; HammerDB does
  not run non-interactively.
- **Uncertain interpretation** marked by the author: the tags `<m>` and `<t>` of
  the `hint_usage` structure ("unsure"); dynamic remastering with "very little
  official documentation".

## [2026-10-01] maintenance | Extraction defect fixed: swallowed SQL code

While answering a question about skipped index columns it emerged that the
archived query was incomplete. Cause: when extracting from the blog HTML, an
unescaped `<` (as a SQL comparison operator) together with the text up to the
next `>` was treated as an HTML tag and removed.

**Extent:** 7 of the 74 posts, 2907 characters in total, exclusively inside SQL
and PL/SQL code. Affected: 25 (2017-09-11), 54 (2023-12-07), 60 (2024-08-20),
64 (2025-01-23), 65 (2025-01-28), 69 (2026-01-14), 71 (2026-06-03).

**Fixed:** the extraction now only removes tags from a whitelist of known HTML
elements. The seven files in `raw/posts/` were rewritten; the correction is noted
in `raw/posts/README.md`.

**Consequences for the wiki:**
- `index-access-paths` **corrected in substance.** The detection criterion was
  too vague, because exactly that part of the query was missing. Now precise:
  `ic.Column_Position <= p.Search_Columns` together with
  `Access_Predicates NOT LIKE '%'||ic.Column_Name||'%'`, with access **and**
  filter predicates both populated. Added as an open question that the text
  search on column names can be a false negative on substring matches.
- `optimizer-hints` extended by the restored example of the DBMS_XPLAN hint
  report (which confirms the mapping of the `st` codes to U/E).
- `network-latency-from-ash`: the query is explicitly stored in `dragnet`, not
  just generally in Panorama.
- Checked but unchanged and correct: the statements in `deterministic` (the
  counter experiment), `unified-audit-trail-operations` (the logged special case)
  and `bind-variables-and-cursor-sharing`.

## [2026-10-01] query | Finding skipped index columns

The user's question: "How do I find indexes where a middle column is not used?"

Answered from `index-access-paths`. The answer was the occasion for finding and
fixing the extraction defect (see the preceding maintenance entry) — the archived
query was incomplete.

Answer kept at the user's request as the first synthesis:
`wiki/syntheses/finding-skipped-index-columns.md`. It contains the detection
criterion as a table, the complete SGA query, the four differences of the AWR
variant, the licence prerequisite, and the placement within the pattern "usage is
no proof of quality" (together with `extended-statistics` and
`partition-pruning` — all three hang on the distinction between access and filter
predicate).

Marked as a conclusion of the wiki (not from the source): the condition
`Access_Predicates NOT LIKE '%'||ic.Column_Name||'%'` is a text search and can be
a false negative for column names contained in others (`ID` in `CUSTOMER_ID`).

Linked from `index.md`, `wiki/overview.md` and `index-access-paths`.

## [2026-10-02] maintenance | Wiki switched to English

The user changed the working principle in `CLAUDE.md` to "Language: English" and
asked for all created artifacts to follow. Per the schema's own rule, the
convention came first and the wiki was then brought in line.

**Scope:** all 74 pages in `wiki/`, plus `index.md`, `log.md`, `CLAUDE.md`,
`CONFIG.md`, `README.md` (title line) and `raw/posts/README.md`. 8052 lines in
total.

**File names translated as well**, on the user's decision — 48 of the 74 pages
were renamed, for instance `ausfuehrungsplaene` → `execution-plans`,
`fremdschluessel-sperren` → `foreign-key-locks`,
`uebersprungene-indexspalten-finden` → `finding-skipped-index-columns`. All
wikilinks were carried along; 26 names were already language-neutral and stayed.

**Deliberately left in German**, now recorded as an exception under *Working
principles* in `CLAUDE.md`:
- `LLM-Wiki-Idee.md` — a German translation of Karpathy's English original;
  translating it back would be pointless.
- `README.md` (body) — documents the template itself, not the subject matter.

**Front matter:** keys and values stay English as before; `tags` were translated
along with the content (`kern` → `core`, `sperren` → `locks`,
`ausfuehrungsplan` → `execution-plan`, `speicher` → `storage`,
`lizenz` → `licensing`, `sicherheit` → `security`, `quelle` → `source`,
`werkzeug` → `tool`, `betrieb` → `operations`, `systemlast` → `system-load`,
`partitionierung` → `partitioning`, `komprimierung` → `compression`,
`statistik` → `statistics`, `netzwerk` → `network`, `diagnose` → `diagnostics`,
`vorgehen` → `procedure`).

**Enriched in passing**, where the translation revealed a gap:
- `awr.md` was a near-empty stub; it now lists what the ingested sources actually
  say about AWR views, with links to the six pages concerned.
- `dragnet.md` now lists all known catalogue entries, not only those from the
  indexing block.
- `panorama-sampler.md` gained the three things it records beyond AWR
  (tablespace object growth, DB cache occupancy, blocking lock details).
- Several pages gained cross-references that were missing in the German version
  (`view-pushed-predicate` ↔ `cross-table-uniqueness`,
  `sequence-caching` → `library-cache-contention`,
  `optimizer-diagnostics` ↔ `sql-monitor`, among others).

**Checked after the change:** 74 pages, 1025 wikilinks, no dead links, no
orphaned pages, front matter complete on every page, `decision_status` present on
all five decision pages.

**Safety net:** the German state was copied to the session scratchpad before the
change (`wiki-backup-de`). The wiki directory is not under version control, so
there was no git fallback.
