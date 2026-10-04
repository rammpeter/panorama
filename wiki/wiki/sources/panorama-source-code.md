---
title: Panorama source repository
type: source
status: maintained
tags: [panorama, architecture]
created: 2026-10-03
updated: 2026-10-03
sources: [panorama-repository.md]
---

# Panorama source repository

The source code of [[panorama]] itself, read as a source for the development
half of this wiki. Raw file: `raw/panorama-repository.md` — a pointer to the
repository root (`../` relative to the wiki, <https://github.com/rammpeter/Panorama>).

**State read:** commit `d887d8d3` of 2026-10-03, `Panorama::VERSION` 2.19.26
(release date 2026-09-16), about 46,500 lines of Ruby and JavaScript outside
`vendor/`.

> Unlike the blog posts, this source is **not frozen**: the pointer stays the
> same while the code moves on. Every statement in `wiki/development/` is true
> for the commit above and may have gone stale since. File paths are given so
> that a claim can be re-checked quickly.

## What was read

| Area | Files | Depth |
|---|---|---|
| Project guidance | `CLAUDE.md`, `README.md`, `CHANGELOG.md` | complete (changelog: 2025–2026 entries) |
| Boot and configuration | `config/application.rb`, `config/routes.rb`, `config/puma.rb`, `config/boot.rb`, `config/database.yml`, `config/jarble.rb`, `config/environments/production.rb`, `config/initializers/*` | complete |
| Request frame | `app/controllers/application_controller.rb`, `app/helpers/application_helper.rb`, `app/helpers/env_helper.rb`, login flow in `app/controllers/env_controller.rb` | complete for the parts named |
| Database access | `app/models/panorama_connection.rb`, `thread_local_storage.rb`, `pack_license.rb`, `encryption.rb`, `client_info_store.rb` | complete |
| Sampler | `app/jobs/*`, `app/models/worker_thread.rb`, `panorama_sampler_config.rb`, `panorama_sampler_sampling.rb`, `panorama_sampler_structure_check.rb`, `app/helpers/panorama_sampler/*` | control flow complete; the PL/SQL bodies and the table definitions only skimmed |
| GUI layer | `app/helpers/ajax_helper.rb`, `slickgrid_helper.rb`, `menu_helper.rb`, `dragnet_helper.rb`, one sample action with its view | interfaces, not every helper |
| Build and test | `build_jar.sh`, `Dockerfile`, `run_Panorama_docker.sh`, deploy scripts, `Gemfile`, `test/test_helper.rb`, `lib/test_helpers/*`, `.github/workflows/*` | complete |

**Not read:** the bodies of the 17 domain controllers (about 22,000 lines of SQL
against Oracle views), the 392 view templates, the JavaScript in
`app/assets/javascripts/` beyond its header, `key_explanation_helper.rb`. They
implement the features described under usage; their content is Oracle knowledge
rather than architecture.

## Key points

**There is no application database.** `config/database.yml` wires the `nulldb`
adapter. Every Oracle connection is opened at request time from credentials the
browser session supplied, and held in a pool of Panorama's own
→ [[panorama-connection]], [[own-connection-pool-outside-activerecord]].

**The connection of a request is bound to its thread.** Connect info and the
connection object live in thread-local storage, encapsulated in
`ThreadLocalStorage`. The same mechanism serves the sampler's worker threads
→ [[panorama-connection]].

**Routes are derived from the controller source text.** `config/routes.rb`
scans `app/controllers/*.rb` line by line and routes every public `def` as
`controller/action`, for GET and POST — except a fixed list of state-changing
actions that are POST only → [[panorama-request-and-rendering]],
[[route-state-changing-actions-post-only]].

**Licence enforcement is a text filter on the SQL.** Every statement passes
`PackLicense.filter_sql_for_pack_license` before execution. It rewrites
`DBA_HIST_*` to the sampler's tables when the sampler is the chosen source, and
raises if the statement still names an object that needs a pack the user has not
confirmed → [[pack-license-filter]].

**The sampler is a set of threads inside the web server.** An ActiveJob wakes
at the smallest configured snapshot cycle and starts one Ruby thread per
configuration and domain; the ASH sampling itself is a long-running PL/SQL call
→ [[panorama-sampler-internals]].

**Server-side state is a file store keyed by a browser cookie.** Login data,
the chosen licence, time selections and personal dragnet SQL live in an
`ActiveSupport::Cache::FileStore` under `PANORAMA_VAR_HOME`, per client key and
per browser tab → [[panorama-client-state-and-security]].

**Passwords are encrypted twice.** In the browser with an RSA public key whose
private half exists only in the running server process; at rest with a key
composed of a per-browser salt cookie and the server's `secret_key_base`
→ [[panorama-client-state-and-security]].

**Every view is an HTML fragment loaded by AJAX into a target `div`.** Tables
are rendered through one generator, `gen_slickgrid`, from a list of column
definitions with Ruby procs → [[panorama-request-and-rendering]].

**Configuration comes from environment variables or a YAML file**, the
environment winning → [[panorama-configuration]].

**The JAR is built with jarbler, the test suite needs a live Oracle database**,
and CI runs it against eleven database variants, each with one randomly chosen
licence setting → [[panorama-build-test-and-release]].

## Impact on the wiki

New, all in `wiki/development/` — the category was empty before:

- [[panorama-architecture]] (entry point)
- [[panorama-connection]]
- [[panorama-client-state-and-security]]
- [[pack-license-filter]]
- [[panorama-sampler-internals]]
- [[panorama-request-and-rendering]]
- [[panorama-configuration]]
- [[panorama-build-test-and-release]]
- Decisions: [[own-connection-pool-outside-activerecord]],
  [[route-state-changing-actions-post-only]]

Changed in `wiki/usage/`: [[panorama]], [[panorama-sampler]], [[dragnet]],
[[management-pack-licensing]], [[panorama-operations]] — open questions answered
from the code, and cross-links into the development pages.

## Where the code disagrees with the blog

- **Who may choose a pack licence.** The blog (2017-12-01) says the two licensed
  options are available for Enterprise Edition only. The code also offers them
  for Express Edition unconditionally and for the Free edition under the same
  parameter check as Enterprise. Both kept in [[management-pack-licensing]].
- **Environment variable names.** The 2019 compose example uses
  `PANORAMA_SAMPLER_MASTER_PASSWORD` and `LOG_LEVEL`. The code reads
  `PANORAMA_MASTER_PASSWORD` (the old name is still accepted) and
  `PANORAMA_LOG_LEVEL`; `LOG_LEVEL` is no longer read anywhere. Recorded in
  [[panorama-operations]] and [[panorama-configuration]].
- **The `/Panorama` path.** The 2019 Nginx example proxies to
  `http://panorama:8080/Panorama`. In the code the application lives at `/` and
  `/Panorama` merely redirects there. Recorded in [[panorama-operations]].
- **Oldest tested database.** The repository's `CLAUDE.md` names 10.2 as the
  lower end of CI; the active jobs in `.github/workflows/main.yml` start at
  11.2.0.4. Recorded in [[panorama-build-test-and-release]].

## Open questions

- The source is a moving target. Should a commit hash be pinned in
  `raw/panorama-repository.md`, or the development pages be re-checked on each
  release?
- The domain controllers were not read. A later pass could map menu entries to
  the Oracle views they query — that would tie the usage pages to the code.
