---
title: Panorama configuration
type: entity
subtype: component
status: draft
tags: [panorama, architecture, operations]
created: 2026-10-03
updated: 2026-10-03
sources: [panorama-repository.md]
---

# Panorama configuration

The settings a [[panorama]] server instance reads at start, where they come from
and what each one does internally. The operator's view — Docker, HTTPS — is in
[[panorama-operations]].

## Summary

All settings are resolved once, in `config/application.rb`, in this order
([[panorama-source-code]]):

1. built-in default
2. YAML file named by `PANORAMA_CONFIG_FILE` (since 2.19.2, changelog 2025-11-12)
3. environment variable of the same name — **wins over the file**

Each resolved value is printed at start; anything with `PASSWORD` in its name is
masked. Keys in the file are case-insensitive. A missing file aborts the start.

## The settings

| Setting | Default | Effect |
|---|---|---|
| `PANORAMA_VAR_HOME` | `<tmpdir>/Panorama` | Directory for everything persistent: client info store, generated `secret_key_base`, `Usage.log`, predefined dragnet file. With the default, saved logins and the sampler configuration do not survive a restart reliably — the log and the login dialog both warn |
| `PANORAMA_MASTER_PASSWORD` | none | Enables the admin menu and the sampler. Also the encryption salt of the stored sampler credentials → [[panorama-sampler-internals]] |
| `MAX_CONNECTION_POOL_SIZE` | 100 | Upper bound of pooled Oracle sessions **and** of Puma threads → [[panorama-connection]] |
| `PANORAMA_LOG_LEVEL` | `info` in production, `debug` otherwise | Rails log level |
| `PANORAMA_LOG_SQL` | `false` | Additionally logs every SQL statement to stdout |
| `PANORAMA_USAGE_INFO_MAX_AGE` | 180 | Retention of `Usage.log`; `0` disables usage logging |
| `SECRET_KEY_BASE` / `SECRET_KEY_BASE_FILE` | generated | → [[panorama-client-state-and-security]] |
| `PANORAMA_CONFIG_FILE` | none | Path of the YAML file; environment only |

Read outside `application.rb`:

| Variable | Where | Effect |
|---|---|---|
| `TNS_ADMIN` | JDBC driver, `tnsnames.ora` parser | Location of `tnsnames.ora` and wallet files. If unset but `ORACLE_HOME` is set, `$ORACLE_HOME/network/admin` is used |
| `PORT` | `config/puma.rb` | Port in development (3000). The JAR passes `-p 8080` explicitly |
| `RAILS_LOG_TO_STDOUT_AND_FILE` | `production.rb` | Log to stdout and to a rotating file (5 × 10 MB) instead of stdout only. Set by the Docker start script |
| `MAX_JAVA_HEAP_SPACE_MB`, `HTTP_PORT` | `run_Panorama_docker.sh` | Container only: JVM heap (default 1024) and port (8080) |
| `TZ` / JVM default time zone | `PanoramaConnection` | Becomes the session time zone of every Oracle connection, and the zone timestamps are shown in |

## Renamed and removed settings

**Contradiction with an older source.** The compose example in
[[blog-panorama-the-tool]] (2019-03-27), reproduced in [[panorama-operations]],
uses names that differ from the current code:

| 2019 example | Current code |
|---|---|
| `PANORAMA_SAMPLER_MASTER_PASSWORD` | `PANORAMA_MASTER_PASSWORD`. The old name is **still accepted**: `application.rb` copies it over if the new one is unset |
| `LOG_LEVEL` | `PANORAMA_LOG_LEVEL`. `LOG_LEVEL` is not read anywhere any more |

The newer source — the code — is preferred. The rename of the master password
reflects that it now guards more than the sampler (admin menu, usage history).

## Constants that are not configurable

Set in code, relevant when reasoning about behaviour:

- Browser session lifetime after the last request: 8 hours
- Idle pooled connections are closed after 1 hour
- Network timeout of a connection: twice the query timeout chosen at login
- Admin token lifetime: 8 hours
- Version and release date: `Panorama::VERSION`, `Panorama::RELEASE_DATE` in
  `config/application.rb` — with a fixed syntax, because release scripts and
  external pages parse them ([[panorama-build-test-and-release]])

## Relationships

- Part of [[panorama-architecture]].
- Operator's view: [[panorama-operations]].

## Open questions

- Is there user-facing documentation of `PANORAMA_CONFIG_FILE` with an example
  file? The repository's `README.md` does not mention it.
- `PANORAMA_USAGE_INFO_MAX_AGE` has no unit in the code that reads it; days are
  likely but unverified.

## Sources

- [[panorama-source-code]]
- [[blog-panorama-the-tool]] (the older variable names)
