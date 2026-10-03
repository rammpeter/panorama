# Archive of rammpeter.blogspot.com

All 74 posts, fetched on 2026-10-01 via the Atom feed
(`https://rammpeter.blogspot.com/feeds/posts/default`).

Every file starts with the title, date, original URL and the Blogger labels,
followed by the text extracted from the HTML. File name:
`<seq. no.>-<date>-<title as kebab-case>.md`, numbered chronologically.

Not included: the screenshots several posts refer to. The feed does not supply
them; where an image carries the message, part of the evidence is missing here.

These files are sources in the sense of `CLAUDE.md`: read only, never change.

## Correction 2026-10-01

On the first extraction, parts of SQL code were swallowed in seven posts: an
unescaped `<` in the HTML (as a comparison operator, say) was treated as an HTML
tag together with the following text up to the next `>`, and removed. 2907
characters in total were affected, exclusively inside SQL.

The extraction now only removes tags from a whitelist of known HTML elements;
everything else is preserved as text. The seven files were rewritten:

- 25-2017-09-11 (literals instead of bind variables)
- 54-2023-12-07 (hint_usage in OTHER_XML)
- 60-2024-08-20 (HASH JOIN SHARED)
- 64-2025-01-23 (network latency from ASH)
- 65-2025-01-28 (cleanup unified audit trail)
- 69-2026-01-14 (DETERMINISTIC flag)
- 71-2026-06-03 (skipped index columns)
