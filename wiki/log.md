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

## [2026-10-03] maintenance | Restructured into usage and development

The user changed the directory structure in `CLAUDE.md`: the page directories
`entities/`, `concepts/` and `decisions/` are replaced by the two categories
**`usage/`** (how to use Panorama for performance analysis) and
**`development/`** (how Panorama works, its architecture and design decisions).
`sources/` and `syntheses/` stay. Per the schema's own rule, the convention came
first and the wiki was then brought in line.

**Moved:** all 61 pages from `wiki/entities/` (6), `wiki/concepts/` (50) and
`wiki/decisions/` (5) into `wiki/usage/`. File names are unchanged, so every
wikilink still resolves. The three old directories were removed.

**`wiki/development/` is empty.** Every existing page rests on the blog, which
describes analysis with Panorama, not its internals. The five decision pages are
recommendations for the analysed database (indexing, compression, cursor
sharing …), not design decisions of Panorama — hence `usage/` too.

**Kept:** the front matter field `type` (`entity | concept | decision | …`) and
with it `decision_status` and lint check 9. The directory now states the
audience, `type` the kind of page. This reading is the LLM's completion of the
user's change, recorded in `CLAUDE.md` under *Where does a page belong?*

Changed: `CLAUDE.md` (the "Where does it belong?" paragraph, the note on
directory vs. `type`, ingest step 4), `index.md` (regrouped into Usage with three
sub-groups, Development, Syntheses, Sources), `wiki/overview.md` (new section
*Structure*, open question reworded), `README.md` (directory tree), the skills
`wiki-ingest`, `wiki-lint` and `wiki-setup` in `.claude/skills/` and
`.github/skills/` (directory references).

Open: a source on Panorama's internals is needed to fill `development/` — the
repository itself (e.g. its `CLAUDE.md`, `config/routes.rb`,
`app/models/panorama_connection.rb`) is the obvious candidate, but is not in
`raw/`.

## [2026-10-03] ingest | Panorama source repository

Source: `raw/panorama-repository.md`, a pointer to the repository root (`../`,
<https://github.com/rammpeter/Panorama>), created at the user's request to fill
the empty development category. Read at commit `d887d8d3`, version 2.19.26.
Processed without a preceding discussion of key points — the user started the
ingest directly after asking for the pointer.

**Read:** project guidance and changelog, boot and configuration, the request
frame, database access, licence filter, encryption and client state, the
sampler's control flow, the GUI helpers, build scripts, test helpers and CI
workflows. **Not read:** the bodies of the 17 domain controllers (about 22,000
lines of SQL), the 392 view templates, the JavaScript, the sampler's PL/SQL
bodies beyond skimming. Listed on the source page.

**New (11):** source page `panorama-source-code`; in `wiki/development/`:
`panorama-architecture`, `panorama-connection`, `pack-license-filter`,
`panorama-sampler-internals`, `panorama-request-and-rendering`,
`panorama-client-state-and-security`, `panorama-configuration`,
`panorama-build-test-and-release`, and the decisions
`own-connection-pool-outside-activerecord` and
`route-state-changing-actions-post-only` (both `adopted`).

**Changed:** `wiki/usage/panorama.md`, `panorama-sampler.md`, `dragnet.md`,
`management-pack-licensing.md`, `panorama-operations.md` (open questions
answered from the code, cross-links into development), `wiki/overview.md`,
`index.md`, `CLAUDE.md` (the repository as a typical source).

**The source page is named `panorama-source-code`**, not after the raw file:
`raw/panorama-repository.md` and a wiki page of the same name would make the
bare wikilink ambiguous.

Contradictions and revisions recorded:
- **Editions that may choose a pack licence.** Blog 2017-12-01: Enterprise
  Edition only. Code: also Free (same parameter check) and Express
  (unconditionally). Both kept in `management-pack-licensing`; open question.
- **Environment variable names.** The 2019 compose example uses
  `PANORAMA_SAMPLER_MASTER_PASSWORD` and `LOG_LEVEL`; the code reads
  `PANORAMA_MASTER_PASSWORD` (old name still accepted) and
  `PANORAMA_LOG_LEVEL`. Noted in `panorama-operations` and
  `panorama-configuration`.
- **`/Panorama` path.** The 2019 Nginx example proxies to `/Panorama`; the code
  serves at `/` and redirects `/Panorama` there. Marked "possibly outdated", not
  tested.
- **Oldest tested release.** The repository's `CLAUDE.md` says 10.2; the active
  CI jobs start at 11.2.0.4.
- **Superseded assessment of this wiki:** `dragnet` said the numbering "appears
  to have been stable". Entries are addressed by tree position only, so numbers
  shift. Old wording kept and marked.

Open questions closed: architecture without a source (`panorama`, `overview`);
how the sampler works technically (`panorama-sampler`); size and structure of
the dragnet catalogue (`dragnet`); running Panorama as a JAR
(`panorama-operations`).

Marked as conclusions of the wiki, not statements of the source: why JRuby; why
an own connection pool (beyond the quoted comments); why only state-changing
actions are POST-only; that CI covers release × licence only statistically; that
the sampler's table list defines its scope; that the trust boundary is the
Oracle login.

New open questions, among others: whether a commit should be pinned in the raw
pointer; unfiltered SQL paths in the licence filter (`exec_clob_plsql_function`);
connections in use beyond twice their timeout; the hand-maintained POST-only
list; the boot-time patch of the Oracle adapter gem.

## [2026-10-04] ingest | Speakerdeck slide decks (14 talks, 2016–2026)

Source: `raw/speakerdeck.md`, a pointer to <https://speakerdeck.com/rammpeter>
with the instruction to read the PDFs. The profile lists 14 decks; all were
downloaded on 2026-10-03 and **archived as PDF in `raw/speakerdeck/`** (37 MB),
following the precedent of `raw/posts/` — the authoritative files now sit inside
the wiki. Processed as a batch at the user's request ("read speakerdeck PDFs"),
without a preceding discussion of key points.

**How they were read.** No PDF renderer (`poppler`) is installed, so the Read
tool could not show pages. Text was extracted from all 14 PDFs with `pypdf`
(installed into the session's scratch directory only). For slides that are
charts or diagrams — the compression talk and the sampler architecture — the
slide images were fetched from Speakerdeck and viewed. **Not viewed:** the
screenshots of Panorama on most other slides; their content is missing from the
wiki. Two SQL listings in the 2016 ASH deck are garbled by letter-spacing in the
PDF text and only partly legible.

**Source pages grouped by topic**, as with the blog: `talks-ash-and-temp` (2
decks), `talks-sql-plan-management` (1), `talks-dragnet-and-proactive-tuning`
(2), `talks-indexes` (3), `talks-panorama-and-sampler` (3),
`talks-advanced-compression` (1), `talks-jarbler-and-movex-cdc` (2).

**New pages (6):** in `wiki/usage/`: `rammpeter-talks` (list of all decks),
`advanced-compression`, `function-based-indexes`,
`proactive-performance-tuning`, `movex-cdc`; in `wiki/development/`: `jarbler`.

**Changed (26):** `panorama`, `panorama-sampler`, `dragnet`, `ash`, `awr`,
`temp-usage`, `session-context`, `blocking-locks`, `sql-plan-management`,
`sql-translation-framework`, `oltp-compression`,
`oltp-compression-only-without-updates`, `index-compression`, `indexing`,
`deterministic`, `cross-table-uniqueness`,
`interval-partitions-rolling-window`, `storage-reorganisation`, `redo-logs`,
`management-pack-licensing`, `bind-variables-and-cursor-sharing`,
`master-data-caching`, `rammpeter-blog`; in development
`panorama-sampler-internals`, `panorama-build-test-and-release`,
`panorama-architecture`; plus `wiki/overview.md` and `index.md`.

Contradictions, revisions and tensions recorded:
- **Decision under tension.** `oltp-compression-only-without-updates` (adopted,
  from the 2018 post) is relativised by the author's talk of 2024-02: for 19c the
  advice is to keep migrated rows in view, not to avoid the feature. Decision
  left `adopted`; the tension is recorded under *Open despite the decision* and
  in the provenance. Three states now stand side by side in `oltp-compression`
  (2018, 2023-05, 2024-02).
- **Index compression saving** is stated four ways across the sources (up to
  half; 1/4 to 1/3; "1/3 to 1/2 of the original size"; up to 30 % or more) and
  measured as 29 % saved or 13 % *added* depending on column order. All kept in
  `index-compression`, with the measurement as the explanation.
- **Dragnet numbering shifts — now evidenced by a source**: the same check is
  point 1.11 in 2018 and 1.15 in 2026. Confirms the conclusion drawn from the
  code on 2026-10-03.
- **Licence of the SQL plan baseline refined**, not contradicted: Enterprise
  Edition for the baseline, Tuning Pack for creating it from AWR.
- **Probable slip in a source**: the 2026 deck writes `cursor_sharing=EXACT`
  where `FORCE` fits. Recorded as written, read as `FORCE`, flagged as an open
  question in `bind-variables-and-cursor-sharing`.
- **Apparent contradiction resolved**: the Jarbler talk (2025-05) shows Rails 8.0
  failing from a JAR, Panorama runs Rails 8.1 from one. Different applications;
  what made the difference is undocumented.
- **Changes over time**, not contradictions: packaging WAR (2022) → JAR (2024);
  sampler releases "to 21" → "to 26ai"; catalogue "just under 100" → "140+".

Open questions closed: the limits of the sampler's ASH (`panorama-sampler`); how
RAC instances are sampled (`panorama-sampler-internals`); measurements for index
compression (`index-compression`).

Marked as conclusions of the wiki: that the choice of compression method follows
the access path; that archive high is hard to justify on the measured numbers;
that TEMP attribution from ASH is a lower bound; that Jarbler's recurring problem
is native extensions and gem clashes and that `excluded_gems.txt` is the answer
to it; that Jarbler replaced Warbler; that the eight performance factors run
from what money buys to what only design fixes.

Scope note: `movex-cdc` lies outside the wiki's stated subject. One page was
created for its Oracle design decisions and marked as marginal.

Still not ingested: `raw/rammpeter.github.io.md`.

## [2026-10-04] maintenance | OLTP compression decision superseded; MOVEX CDC in scope

Two decisions by the user, answering the open questions of the Speakerdeck
ingest. Both rest on **statements by the user in the session**, not on a source
in `raw/`.

**1. Decision superseded.** `oltp-compression-only-without-updates` changed from
`adopted` to `superseded`. Successor, newly created and `adopted`:
`monitor-migrated-rows-under-advanced-compression` — advanced compression may be
used on updated tables from release 19; the condition is that migrated rows are
monitored. Substance from the talk of 2024-02 and the blog addendum of 2023-05.
The old page is kept as the record of the earlier position (still the safe rule
for 12.x and 18.x); its open points were not deleted, and those that still apply
were carried into the successor as implementation risks: no monitoring routine
or threshold is defined, "not deterministic" is unexplained, no measurements for
19c, nothing verified beyond 19.18.

Status drift checked: every mention of the old decision now says superseded or
points to the successor — `index.md`, `wiki/overview.md`, `oltp-compression`,
`advanced-compression`, `talks-advanced-compression`, `blog-storage`.

**2. MOVEX CDC.** Confirmed as mentionable; the "marginal / edge of the subject"
remarks were removed from `movex-cdc`, `talks-jarbler-and-movex-cdc` and
`index.md`. Project address corrected to
<https://gitlab.com/osp-silver/oss/movex-cdc>; the address printed on the 2022 slides
(`gitlab.com/otto-group-solution-provider/movex-cdc`) is kept on the page as
what the source says. Open: whether documentation and Docker image moved too.

## [2026-10-04] maintenance | Slip in the 2026 talk confirmed

The author confirmed that "`cursor_sharing=EXACT`" on slide 22 of
`raw/speakerdeck/2026-05_DOAG_Datenbank_Firefighting_or_Fixing_Root_Causes.pdf`
("4.1.1 .. 4.1.5 Missing use of bind variables") should read `FORCE`. A user
statement in the session. Noted in `bind-variables-and-cursor-sharing` and
`talks-dragnet-and-proactive-tuning`; the archived PDF stays as it is, the
published deck on Speakerdeck still carries the wrong word.
