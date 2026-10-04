---
title: Own connection pool outside ActiveRecord
type: decision
decision_status: adopted
status: draft
tags: [panorama, architecture, session]
created: 2026-10-03
updated: 2026-10-03
sources: [panorama-repository.md]
---

# Own connection pool outside ActiveRecord

**Status: adopted.** [[panorama]] configures Rails with a null database and
manages all Oracle connections itself, in [[panorama-connection]], bound to the
executing thread.

## The choice

- `config/database.yml` declares the `nulldb` adapter for every environment.
- Oracle sessions are opened at request time from credentials supplied by the
  browser session, kept in a pool owned by `PanoramaConnection`, and looked up by
  JDBC URL, user and password hash.
- Of the `oracle_enhanced` adapter only the low-level `JDBCConnection` class is
  used, extended by a streaming `iterate_query`.

## The rationale

Stated in the code:

> "Holds DB-Connection(s) to several Oracle-targets thread-safe apart from
> ActiveRecord" — `panorama_connection.rb`

> "Panorama has no static DB connection. Instead the connect info of the current
> request and the used DB connection object are bound to the executing thread" —
> `thread_local_storage.rb`

> "hold open SQL-Cursor and iterate over SQL-result without storing whole result
> in Array" — `panorama_connection.rb`, dated 2016-03-02

> Conclusion (this wiki's reading, not a statement in the source): ActiveRecord
> assumes a fixed, small set of databases known at boot, one schema, and model
> classes mapped to tables. Panorama has the opposite on every count — the
> target is chosen per browser tab, each user logs in with their own Oracle
> account so that Oracle's privileges decide what they may see, and there are no
> tables to map. A per-credential pool keyed at runtime is the direct expression
> of that, and it gives the sampler's threads the same mechanism for free
> ([[panorama-sampler-internals]]).

## Consequences

- **A single choke point.** Because all SQL goes through one class, the
  [[pack-license-filter]], the time zone shift, the query timeout and the error
  enrichment are applied uniformly.
- **Ownership of the hard parts.** Pool limits, ageing, eviction after errors,
  stuck sockets and shutdown are Panorama's code, not the framework's
  ([[panorama-connection]]).
- **Coupling to adapter internals.** `iterate_query` is added by reopening an
  adapter class, a private instance variable is exposed through a getter, and one
  adapter file is patched at boot ([[panorama-build-test-and-release]]). Adapter
  upgrades can break these silently.
- **Rails tasks that expect a database** have to be removed
  (`lib/tasks/panorama_tasks.rake`).

## Open despite the decision (implementation risks)

- A connection in use for longer than twice its query timeout is only logged,
  not freed. Its release depends on the JDBC network timeout firing.
- Pool lookup iterates the whole array under one mutex; with the default limit
  of 100 that is negligible, with a much larger limit less so.

## Provenance

Derived from the source code as read on 2026-10-03 (commit `d887d8d3`). The
streaming iterator carries the date 2016-03-02; when the null database was
introduced is not recorded in the files read. No discussion or document outside
the code was available — the rationale beyond the quoted comments is this wiki's
conclusion and marked as such.

## Sources

- [[panorama-source-code]]
