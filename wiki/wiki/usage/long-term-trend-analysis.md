---
title: Long-term trend analysis
type: concept
status: draft
tags: [ash, system-load, licensing, oracle]
created: 2026-10-01
updated: 2026-10-02
sources: [blog.md, posts/]
---

# Long-term trend analysis

The evolution of database load across **years** — the basis for hardware
planning and investment decisions. [[ash]] does not suffice for that: retained
too briefly, resolved too finely.

## Why the built-in means do not suffice

([[blog-system-load]], 2022-06-10) The retention of ASH is 7 days by default,
usually about 30 in production. The author rejects two obvious ways out:

- **Increasing the ASH retention to years** — leads to a volume of data that is
  "cumbersome or impossible to handle".
- **AWR Warehouse in Enterprise Manager Cloud Control** — may fit, but means
  "inappropriate effort", particularly for single or few instances.

## The route: condense instead of retain

[[panorama-sampler]] extracts information from ASH and stores it **condensed** as
a summary over periods between one hour and one day. What is stored is the summed
active time of all sessions per snapshot period, broken down by eight attributes:

instance number · wait class · wait event · user name · TNS service name ·
machine · module · action

The same dimensions as in ASH — only without the individual sample.

### Two controls for the data volume

- Per attribute you can decide whether the active time is recorded for **every**
  occurrence or not.
- A **"subsume limit"** groups less relevant values of an attribute under
  `[OTHERS]`.

### The order of magnitude

> At one snapshot per day the storage requirement is about **1/1000** of the ASH
> source data.
>
> Backed by a concrete figure: for a heavily used 10 TB system the stored
> long-term ASH of the **last four years takes roughly 55 MB** at a resolution of
> one day.

## The side effect: no licence needed

The long-term data can be fed from real ASH **or** from Panorama's own,
ASH-like sampling.

> "This way you don't really need EE and Diagnostics Pack. Sampling this
> long-term trend data also works for Standard Edition."

See [[management-pack-licensing]].

## Evaluation

In [[panorama]] via the menu entry "Long-term trend", following the same pattern
as the ASH evaluation: choose the period and the first grouping attribute, look at
the evolution in the chart, and drill down further via the number of occurrences
of an attribute — "User-Name", say.

## Relationships

- Condenses [[ash]]; capture via [[panorama-sampler]].
- The short-term equivalent: [[measuring-system-load]].
- Works around [[management-pack-licensing]].

## Open questions

- Which evaluations are lost through the condensing? Individual SQL IDs and
  sessions are not in the attribute list.
- How is load subsumed under `[OTHERS]` interpreted later — as a catch-all with
  no meaning?
- Can the condensing be changed after the fact, or is the decision about the
  attributes final at capture time?

## Sources

- [[blog-system-load]]
