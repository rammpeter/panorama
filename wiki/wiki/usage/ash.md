---
title: ASH (Active Session History)
type: concept
status: draft
tags: [core, oracle]
created: 2026-10-01
updated: 2026-10-05
sources: [blog.md, posts/, speakerdeck.md, speakerdeck/, rammpeter.github.io.md, rammpeter.github.io/]
---

# ASH (Active Session History)

A once-per-second sample of all active sessions: Oracle records *who* was doing
*what* and *what they were waiting on* — in the ring buffer
`GV$ACTIVE_SESSION_HISTORY`, persisted as a subset in
`DBA_HIST_ACTIVE_SESS_HISTORY`.

## Summary

ASH is the data foundation of most retrospective analyses in this wiki:
[Blocking locks](blocking-locks.md) reconstructs lock hierarchies from it,
[Index access paths](index-access-paths.md) uses it to weight expensive index accesses,
[Estimating network latency from ASH](network-latency-from-ash.md) estimates network latency from it,
[Library cache contention](library-cache-contention.md) finds the hot objects through it.

The most important dimensions: session, SQL ID, wait event and wait class, module
and action (→ [Session context](session-context.md)), machine, object affected, plan line.

**Licence:** Enterprise Edition and the Diagnostics Pack — or alternatively
[Panorama Sampler](panorama-sampler.md), which [Panorama](panorama.md) evaluates *transparently in the same
way*. See [Management pack licensing](management-pack-licensing.md).

## The blind spot: idle waits

The single most important limitation, and the author explicitly comes from a
different assumption ([Blog series on system load and monitoring](../sources/blog-system-load.md), 2017-04-14):

> "As the name implies one would expect that Active Session History records all
> information to reconstruct the main activities of sessions that are active for
> a longer period. Is it really true? **I thought so before, but it isn't.**"

**ASH does not record wait states of the wait class "idle".**

The documented case: a session runs for about an hour as *one* call of a PL/SQL
package method. Continuous activity would be expected. The ASH report instead
shows the session as mostly idle — it consumes time but allegedly does nothing.

The cause was a frequently executed SQL that, because of a `PARALLEL` hint, ran
**accidentally** in parallel query mode, at only a few milliseconds of execution
time each. In `V$SESSION_WAIT` the following showed up:

- The query coordinator waited mostly on `PX Deq Credit: send blkd` — wait class
  **idle**.
- The parallel query slaves on `PX Deq: Execution Msg` — also **idle**.

**And `V$SQL.ELAPSED_TIME` does not count these idle waits either.** So the
search for SQL with conspicuous runtime did not lead to the cause either.

> Conclusion from the source: in some cases it is indispensable to look at the
> process **at runtime**, because idle waits appear neither in ASH nor in
> `V$SQL` — and they are precisely what explains the runtime.

[Dragnet Investigation](dragnet.md) has a dedicated search for extremely short-running SQL in parallel
query mode for this. See also [Parallel execution](parallel-execution.md).

## Further limits

- **The one-second interval is too coarse for short events.** For the search for
  short-lived sessions it is "much too large in most cases" →
  [Short-lived sessions](short-lived-sessions.md).
- **The retention is short.** 7 days by default, usually about 30 in production.
  For year-on-year comparisons condensing is needed →
  [Long-term trend analysis](long-term-trend-analysis.md).
- Only a subset of the ring buffer is carried over into the history.

## Two sources, read as one

([Talks on Active Session History and TEMP analysis](../sources/talks-ash-and-temp.md), 2016.) Oracle keeps every active session once per
second in memory (`gv$Active_Session_History`) and persists every tenth second
with the AWR snapshots (`DBA_Hist_Active_Sess_History`). [Panorama](panorama.md) reads both
in one query: the 10-second history only *up to the oldest sample still in
memory*, then `UNION ALL` the one-second samples — each row weighted by its
`Sample_Cycle` of 10 or 1, so that sums of "seconds waited" stay comparable.

The effect: an evaluation is not bounded by the last AWR snapshot but reaches to
the current second, and the user never chooses between "current" and "historic"
ASH.

> Conclusion: this overlay is also why the [Pack licence filter](../development/pack-license-filter.md) has to rename
> `gv$Active_Session_History` before rewriting SQL for the sampler: both halves
> of the query must be redirected together.

The author's verdict in the same talk: ASH is "for me the biggest step in the
analysis functions of the Oracle database".

The [Panorama Sampler](panorama-sampler.md)'s replacement for ASH lacks three things — plan line,
recursive SQL, I/O figures; see there.

## Relationships

- Complements [AWR](awr.md): ASH supplies the detail resolution, AWR the aggregates.
- Requires a licence — see [Management pack licensing](management-pack-licensing.md); substitute:
  [Panorama Sampler](panorama-sampler.md).
- Underpins [Blocking locks](blocking-locks.md), [Index access paths](index-access-paths.md),
  [Estimating network latency from ASH](network-latency-from-ash.md), [Library cache contention](library-cache-contention.md),
  [Measuring system load](measuring-system-load.md).
- [Panorama](panorama.md) also presents ASH data as a real-time dashboard.
- The view in Panorama that evaluates it: [Session waits](session-waits.md). The usage guide on
  the website describes the overlay of the one-second and ten-second sources in
  the same terms as above ([Panorama's website on GitHub Pages](../sources/rammpeter-github-io.md)).

## Open questions

- How much does the sampling distort results for short observation windows?
- What proportion of the buffer entries actually ends up in the persisted
  history?
- Are there further wait events classified as "idle" although they represent real
  waiting time? The post names two from the parallel query area.

## Sources

- [Blog series on system load and monitoring](../sources/blog-system-load.md)
- [Blog series on locks and serialisation](../sources/blog-locks.md)
- [Blog series on indexing](../sources/blog-indexing.md)
- [Talks on Active Session History and TEMP analysis](../sources/talks-ash-and-temp.md)
- [Talks on Panorama and the Panorama Sampler](../sources/talks-panorama-and-sampler.md)
- [Panorama's website on GitHub Pages](../sources/rammpeter-github-io.md)
