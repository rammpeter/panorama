---
title: TEMP usage
type: concept
status: draft
tags: [storage, ash, oracle]
created: 2026-10-01
updated: 2026-10-02
sources: [blog.md, posts/]
---

# TEMP usage

If `ORA-1652: unable to extend temp segment` appears in the alert log, the
session reported is often **not** the guilty one.

## Two possible causes

([[blog-storage]], 2016-03-23)

1. The session that receives the error has itself allocated a lot of TEMP and has
   reached the end of the available space.
2. **Other** sessions successfully allocated large amounts — and this session,
   with only a small requirement, gets the error.

> The second case is the insidious one: the error hits whoever chance hits. The
> question is therefore not "what did this session do?" but "who was occupying
> the space at that moment?"

## The route to the answer

In [[panorama]] via "Schema / Storage" / "Temp usage" / "Historic":

1. Choose the period and time unit, sort by "Max. TEMP allocated" and display the
   column as a chart — that locates the peak in time.
2. From the peak minute, go via the "Total time waited" column into the [[ash]]
   evaluation of that minute, grouped by RAC instance to begin with.
3. Via "Session / Sn." descend to session level for the instance with the highest
   "Max. temp", remove the instance filter if necessary and sort descending by
   "Max. temp".

That leaves the sessions that occupied the space on screen — together with their
execution context, SQL, wait events and affected objects.

**A pitfall with parallel query:** "Max. temp" only shows the **maximum across
coordinator and slaves**, not their sum. For the actual allocation you have to
look in the "Parallel query" column at what this coordinator's slaves consumed.

## Relationships

- The data foundation is [[ash]] — and therefore
  [[management-pack-licensing]] or [[panorama-sampler]].
- The same basic problem in the permanent tablespace:
  [[tablespace-fragmentation]].
- Parallel query as a disturbance to the measurement:
  [[parallel-execution]].

## Open questions

- Why does "Max. temp" show the maximum rather than the sum across the parallel
  query processes? The source states it but does not explain it.
- Can TEMP allocation also be limited *preventively*, per user or resource group,
  say? Not covered in the post.

## Sources

- [[blog-storage]]
