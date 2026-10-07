---
title: Session list
type: entity
subtype: component
status: draft
tags: [panorama, menu, sessions]
created: 2026-10-05
updated: 2026-10-05
sources: [rammpeter.github.io.md, rammpeter.github.io/Oracle_performance_analysis_with_Panorama.html, rammpeter.github.io/panorama_content_generated.html]
---

# Session list

The menu entry "DBA general" / "Sessions" of [Panorama](panorama.md): the currently
connected database sessions, and the entry point into everything a single
session is doing.

## Use

([Panorama's website on GitHub Pages](../sources/rammpeter-github-io.md), usage guide 2.1.1; menu overview: "Show info of current
DB-sessions".)

- The list is **sorted by the sum of logical and physical block accesses** of
  the session — the busiest sessions come first, not the oldest.
- By default it is **limited to active sessions**.
- Filters narrow it by user, machine, process ID, module and more.
- A click in the column **"SID/SN"** opens the detail view of one session,
  including its **current and its previous SQL**.
- Buttons in the detail view lead further — among them the history of exactly
  this session in [ASH](ash.md), and the "SQL Monitor" button ([SQL Monitor](sql-monitor.md)).

## The Oracle side

The list is the current-state view of the first of the three pillars in
[Analysis workflows in Panorama](panorama-analysis-workflows.md). It answers "who is connected and working right
now"; what the active ones are *waiting on* is the neighbouring view
[Session waits](session-waits.md), and who is blocking whom is [Blocking locks](blocking-locks.md).

The module filter is only as good as the application's tagging: without
`DBMS_APPLICATION_INFO.SET_MODULE` all sessions of a connection pool look alike
→ [Session context](session-context.md).

> Conclusion: the sort order makes this a load view rather than an inventory. A
> session that is connected but has done little sinks to the end; with the
> default filter on active sessions it does not appear at all. For the opposite
> question — many short sessions that are gone before you look — the list is the
> wrong tool; see [Short-lived sessions](short-lived-sessions.md).

## Relationships

- Listed in [Panorama menu overview](panorama-menu-overview.md).
- Retrospective counterpart: [ASH](ash.md) via [Session waits](session-waits.md).
- Statistics of sessions that have ended: [Sampling session statistics yourself](sampling-session-statistics.md).

## Open questions

- Which views the list reads (`gv$Session` joined with session I/O statistics is
  the obvious guess) is not stated on the website; the repository would tell.
- The full set of filters and of buttons in the detail view is not listed in any
  source.

## Sources

- [Panorama's website on GitHub Pages](../sources/rammpeter-github-io.md)
