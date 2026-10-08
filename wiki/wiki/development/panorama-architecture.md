---
title: Panorama architecture
type: entity
subtype: system
status: draft
tags: [core, panorama, architecture]
created: 2026-10-03
updated: 2026-10-08
sources: [panorama-repository.md]
---

# Panorama architecture

How [Panorama](../usage/panorama.md) is built: a Rails application on JRuby without a database of its
own, which opens Oracle connections per request and renders the target
database's system views as HTML fragments. Entry point to the development half
of this wiki.

## Summary

Three properties shape everything else ([Panorama source repository](../sources/panorama-source-code.md)):

1. **No static database.** The application has no schema, no migrations and no
   models in the ActiveRecord sense. `config/database.yml` configures the
   `nulldb` adapter only to keep Rails content
   → [Own connection pool outside ActiveRecord](own-connection-pool-outside-activerecord.md).
2. **One process, many target databases.** Each browser tab can be logged in to
   a different Oracle database with different credentials. What ties a request
   to its database is state on the server keyed by a cookie, and a connection
   bound to the executing thread → [PanoramaConnection](panorama-connection.md),
   [Client state and security in Panorama](panorama-client-state-and-security.md).
3. **SQL is the application logic.** The controllers consist mostly of SQL
   against `V$`, `GV$`, `DBA_*` and `DBA_HIST_*` views. There is no domain
   model between the query and the grid that shows it
   → [Controllers, routing and rendering in Panorama](panorama-request-and-rendering.md).

## The stack

| Layer | Choice | Evidence |
|---|---|---|
| Runtime | JRuby 10.1 on Java 21+ | `.ruby-version`, `README.md`, `CHANGELOG.md` (2025-07-29) |
| Framework | Rails 8.1, loaded piecemeal — no ActionMailer, ActionCable, ActiveStorage | `Gemfile`, `config/application.rb` |
| Web server | Puma, threads only (no workers on JRuby) | `config/puma.rb` |
| Database access | Oracle JDBC thin driver through `activerecord-oracle_enhanced-adapter`, used below the ActiveRecord layer | `app/models/panorama_connection.rb` |
| Frontend | Server-rendered ERB fragments, jQuery, SlickGrid, flot, CodeMirror, superfish; Sprockets asset pipeline | `app/assets/javascripts/application.js`, `vendor/assets/` |
| Background work | ActiveJob with the in-process adapter, plus plain Ruby threads | `config/initializers/initialize_jobs.rb`, `app/models/worker_thread.rb` |
| Packaging | Self-contained `Panorama.jar` via [Jarbler](jarbler.md), or a Docker image | [Building, testing and releasing Panorama](panorama-build-test-and-release.md) |

> Conclusion: JRuby is not incidental. The JDBC thin driver removes the need for
> an Oracle client installation, real threads make one process serve many
> long-running queries, and a single JAR is the distribution format. The code
> refuses to connect on any other Ruby (`"Native ruby … is no longer
> supported"` in `PanoramaConnection`).

## Where things live

| Path | Content |
|---|---|
| `app/controllers/` | 18 controllers, one per functional domain. The five largest hold 2,600–3,800 lines each |
| `app/views/` | 392 partials, almost all named `_list_*` or `_show_*`, each rendering one fragment |
| `app/helpers/` | The real framework: `application_helper.rb` (session, parameters, rendering), `ajax_helper.rb`, `slickgrid_helper.rb`, `menu_helper.rb`, `dragnet/` (the dragnet catalogue), `panorama_sampler/` (PL/SQL package sources) |
| `app/models/` | Not persistence models but infrastructure: `PanoramaConnection`, `ThreadLocalStorage`, `PackLicense`, `ClientInfoStore`, `Encryption`, the sampler classes |
| `app/jobs/` | Three recurring jobs |
| `config/initializers/` | Secrets, job start, shutdown hook, CSP |
| `lib/` | Oracle JDBC jars (`ojdbc11.jar`, `ojdbc17.jar` and companions), rake tasks, test helpers |
| `test/` | Controller, model, job and Playwright system tests |

## Life of a request

Assembled from `application_controller.rb` and `application_helper.rb`:

1. **Parameter screening.** `check_params_4_vulnerability` rejects any parameter
   containing HTML tags from a block list or an inline event handler.
2. **Locale** is read from the client state.
3. **Browser tab.** Every request carries `browser_tab_id`; without it the
   request fails. A handful of actions that need no database are exempt
   (`@@METHODS_WITHOUT_DB_CONNECTION`).
4. **Connect info.** The current database of this client key and tab is read
   from the [client info store](panorama-client-state-and-security.md) and pinned
   to the thread, together with the salt cookie and the controller/action name.
5. **Usage record.** One line per request is appended to `Usage.log`.
6. **The action runs.** The first SQL statement fetches a connection from the
   pool or logs in; every statement passes the [Pack licence filter](pack-license-filter.md).
7. **Render.** The action renders a partial into the `div` named by the
   `update_area` parameter.
8. **Release.** `after_request` marks the connection as free in the pool and
   clears the thread's state.

An exception anywhere **destroys** the connection rather than returning it to
the pool, so the next request starts with a fresh session
(`global_exception_handler`). `PopupMessageException` is the one exception class
meant for the user: it is shown as a message without a stack trace.

## Background work

`config/initializers/initialize_jobs.rb` starts three self-rescheduling jobs
shortly after boot:

| Job | Cycle | Task |
|---|---|---|
| `InitializationJob` | once | logs the memory state |
| `ConnectionTerminateJob` | hourly | closes pooled connections idle for more than an hour (in effect 1–2 hours, see [PanoramaConnection](panorama-connection.md)), cleans the client info store, trims `Usage.log` |
| `PanoramaSamplerJob` | smallest configured snapshot cycle | starts the sampler threads → [Panorama Sampler internals](panorama-sampler-internals.md). Only scheduled if a master password is configured |

At process exit, `config/initializers/shutdown_hooks.rb` aborts every pooled
JDBC connection — a thread blocked in a JDBC call cannot be interrupted any
other way, and the JVM would otherwise wait for the query to finish.

## What is persistent

Panorama writes only into `PANORAMA_VAR_HOME` ([Panorama configuration](panorama-configuration.md)):

- `client_info.store/` — the file store with all client state, including saved
  logins and the sampler configuration
- `secret_key_base` — the generated encryption secret, if none was supplied
- `Usage.log` — the usage record
- `predefined_dragnet_selections.json` — optional, site-wide dragnet additions
  ([Dragnet Investigation](../usage/dragnet.md))

Everything else is in the target databases: the sampler's tables live in a
schema of the database being sampled.

## Relationships

- The product seen from outside: [Panorama](../usage/panorama.md); running it:
  [Panorama operations](../usage/panorama-operations.md).
- Components: [PanoramaConnection](panorama-connection.md), [Pack licence filter](pack-license-filter.md),
  [Panorama Sampler internals](panorama-sampler-internals.md), [Client state and security in Panorama](panorama-client-state-and-security.md),
  [Controllers, routing and rendering in Panorama](panorama-request-and-rendering.md), [Panorama configuration](panorama-configuration.md).
- Decisions: [Own connection pool outside ActiveRecord](own-connection-pool-outside-activerecord.md),
  [Route state-changing actions as POST only](route-state-changing-actions-post-only.md).
- A sibling application on the same base (Rails, JRuby, worker threads,
  self-initialising schema): [MOVEX CDC](../usage/movex-cdc.md).

## Open questions

- Traces of an earlier life as a **Rails engine** embedded in other
  applications are spread across the code (`MenuExtensionHelper`,
  `EnvExtensionHelper.check_credentials`, comments about "use as engine", a WAR
  file name in a path-length check). Is the engine use still supported, or are
  these remnants?
- The usage log records client IP, database, controller and action. Is there a
  documented retention beyond the configurable maximum age?

## Sources

- [Panorama source repository](../sources/panorama-source-code.md)
