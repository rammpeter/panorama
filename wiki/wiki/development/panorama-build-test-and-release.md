---
title: Building, testing and releasing Panorama
type: concept
status: draft
tags: [panorama, architecture, testing, release]
created: 2026-10-03
updated: 2026-10-04
sources: [panorama-repository.md]
---

# Building, testing and releasing Panorama

How a change to [Panorama](../usage/panorama.md) becomes a tested `Panorama.jar` and a Docker image:
the test suite and what it needs, the CI matrix, and the packaging.

## Summary

Two facts dominate ([Panorama source repository](../sources/panorama-source-code.md)):

- **Almost every test needs a live Oracle database.** There is nothing to mock:
  the application consists of SQL against system views. The matrix of database
  releases, editions, container types and licence settings is therefore the
  real test design.
- **The deliverable is one self-contained file.** The JAR contains JRuby, the
  gems, the application and the JDBC drivers.

## Tests

| Directory | Kind |
|---|---|
| `test/controllers/` | one file per controller; the bulk of the suite |
| `test/models/` | connection, licence filter, encryption, client info store, sampler classes |
| `test/jobs/` | the sampler job |
| `test/system/` | browser tests with Playwright (`PlaywrightSystemTestCase`), not Selenium |
| `test/integration/` | navigation |
| `test/test_panorama_jar.rb` | starts the built JAR and requests the start page |

**Connection.** `PanoramaTestConfig` builds the connect info from
`TEST_HOST`, `TEST_PORT`, `TEST_SERVICENAME` (or `TEST_TNS`), `TEST_USERNAME`,
`TEST_PASSWORD`, `TEST_SYSPASSWORD`, with defaults pointing at
`localhost:1521/ORCLPDB1` and user `panorama_test`. Tests call
`connect_oracle_db`. The query timeout in tests is 15 minutes.

**Licence.** `MANAGEMENT_PACK_LICENSE` selects which of the four settings the run
simulates (default: both packs). A test of a licensed feature asserts with
`assert_response_success_or_management_pack_violation`, which expects an error
response for the licence settings passed to it and success otherwise — so the
[Pack licence filter](pack-license-filter.md) is itself under test in every run.

**Menu coverage for free.** `call_controllers_menu_entries_with_actions` walks
the menu structure and requests every entry that belongs to the controller under
test and is valid for the database version. A new menu entry is thus smoke-tested
without a test being written for it ([Controllers, routing and rendering in Panorama](panorama-request-and-rendering.md)).

**Framework adjustments.** `lib/tasks/panorama_tasks.rake` removes the
`db:test:load` and migration-check tasks, which make no sense with the `nulldb`
adapter, and prints the effective test environment. CSRF protection is switched
off in the test environment; the browser tab id is fixed to 1.

## Continuous integration

`.github/workflows/main.yml`, on self-hosted runners, on every push to `master` or `pramm`
and nightly (the nightly run also keeps a free autonomous database alive):

**Database variants actually enabled:**

| Release | Variants |
|---|---|
| Autonomous (cloud) | PDB |
| 11.2.0.4 EE | — |
| 12.1.0.2 EE | — |
| 12.2.0.1 EE | CDB, PDB |
| 19.10 EE | PDB |
| 19.10 SE2 | CDB, PDB |
| 21.3 EE | PDB |
| 21.3 SE2 | PDB |
| 23.5 Free | CDB, PDB |

18c and several CDB variants are present but commented out. Databases run as
containers from prebuilt images (`test/docker/`).

**One licence per run, chosen at random.** `run_tests.yml` declares a matrix of
the four licence settings but then draws one at random and skips the other
three, "to reduce test time". Each database variant is tested with a different
licence setting from run to run.

> Conclusion: full coverage of release × licence is reached only statistically
> over many runs. A failure specific to one combination can pass CI several
> times before it shows up — and when it does, the same commit may pass again on
> a re-run. Worth knowing when a red build cannot be reproduced.

On Standard Edition the run is skipped outright if the drawn licence is a
Diagnostics setting.

**After the tests:** the Docker image is built, started and probed, then pushed;
the JAR is built and started on Ubuntu, macOS and Windows with Java 21 and 24.

**Separately,** `brakeman.yml` runs the Brakeman security scan and uploads the
result as SARIF.

**Contradiction, minor.** The repository's `CLAUDE.md` says CI covers "10.2
through 23c". No 10.2 job exists in the workflow; the oldest is 11.2.0.4. The
workflow file is the more authoritative source. The application code still
contains branches for older releases.

## Building the JAR

`build_jar.sh`:

1. clear `tmp/`, `log/` and old assets
2. `bundle install` with all groups, then `rake assets:precompile` (needs Node
   for the minifier). A task extension in `lib/tasks/precompile.rake` also copies
   each fingerprinted asset to its plain name, for references that bypass the
   asset pipeline
3. `bundle install` again without `development` and `test`
4. `jarble` — [Jarbler](jarbler.md), a tool by the same author — packs everything according to `config/jarble.rb`: executable
   `bin/rails server -e production -p 8080`, Java release 21, Ruby files not
   precompiled, `vendor/` excluded
5. remove the precompiled assets again, so the working tree stays a development
   tree

`excluded_gems.txt` lists gems to leave out of the JAR because they cause
version clashes at start (`erb`, `irb`, `minitest` and others); the `Gemfile`
reads the same file and declares them `require: false`.

## Building the image

`Dockerfile`, two stages on `eclipse-temurin:25`: the build stage installs JRuby
from Maven Central, bundles without development and test gems and precompiles
assets; the final stage copies JRuby and the application onto the JRE image. The
container does **not** run the JAR but `bin/rails server` through
`run_Panorama_docker.sh`, with `exec` so that `docker stop` reaches Puma. The
health check requests the start page.

## Releasing

- The version is bumped by hand in `config/application.rb`; scripts extract it
  with `grep`/`cut`, hence the comment that its syntax and position must not
  change.
- `deploy_github.sh` creates a GitHub release with `Panorama.jar` attached.
- `deploy_dockerhub.sh` tags and pushes `rammpeter/panorama:latest` and
  `:<version>`; CI does the same when the version is new.
- User-visible changes are recorded in `CHANGELOG.md`, newest first, under a
  `## Next` heading until released.

## A dependency patched at boot

`config/boot.rb` rewrites a line in the installed
`activerecord-oracle_enhanced-adapter` gem at every start, to disable a code
path that fails on JRuby 9.4.6+ (dated 2024-06-18, with a reference to the
upstream pull request). The patch is re-applied each time because a reinstalled
gem would lose it.

> Conclusion: the application modifies files outside its own tree at start. In a
> read-only gem directory this write would fail — relevant for hardened
> container setups.

## Relationships

- Part of [Panorama architecture](panorama-architecture.md).
- What the artefacts are used for: [Panorama operations](../usage/panorama-operations.md).
- Settings that tests and containers pass in: [Panorama configuration](panorama-configuration.md).
- The packaging tool and its rough edges: [Jarbler](jarbler.md).

## Open questions

- Is the upstream fix for the adapter merged, so that the boot-time patch can
  go?
- How long does a full CI run take, and is the random licence draw still needed?

## Sources

- [Panorama source repository](../sources/panorama-source-code.md)
