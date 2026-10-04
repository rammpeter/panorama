---
title: Dynamic remastering
type: concept
status: stub
tags: [rac, oracle]
created: 2026-10-01
updated: 2026-10-02
sources: [blog.md, posts/]
---

# Dynamic remastering

In a RAC cluster one instance is the "master" for each object's lock management.
Dynamic Resource Management (DRM) moves that assignment at runtime — depending on
which instance predominantly uses the object.

## The state of the sources

The post [[blog-panorama-the-tool]] (2019-03-28) opens with a qualification:

> "Unfortunately, dynamic remastering in RAC clusters has very little official
> documentation."

Instead the author refers to three external blogs (oracleinaction.com,
hhutzler.de, orainternals.wordpress.com). This page carries the same uncertainty:
what is written here rests on observation and on other people's posts, not on
Oracle documentation.

## The two views

| View | Content |
|---|---|
| `V$GCSPFMASTER_INFO` | the **current** instance affinity per object |
| `GV$POLICY_HISTORY` | the **history** of DRM events |

## In Panorama

- In the object detail view, the master instance of the object is shown — of a
  table, for instance. A click on the instance number shows the complete DRM
  event history of that object.
- Under "Analyses/Statistics" / "RAC-related analysis" / "Dynamic remastering
  events historic": the distribution of events over time and RAC instance as a
  table and a chart, down to the individual event — as well as the objects
  affected in the period, likewise down to the individual event.

Both tables and indexes as well as their partitions can be analysed this way.

## Relationships

- A RAC topic like the per-instance view in [[blocking-locks]] and
  [[measuring-system-load]].
- With parallel processing across instances it also affects
  [[parallel-execution]].

## Open questions

- **When** does Oracle trigger a remastering — by what thresholds?
- What performance effect does a DRM event have, and when is a high DRM rate a
  problem? The post shows how to make it visible, not how to assess it.
- Can DRM be switched off or limited, and when is that sensible?

## Sources

- [[blog-panorama-the-tool]]
