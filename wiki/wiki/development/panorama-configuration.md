---
title: Panorama configuration
type: entity
subtype: component
status: draft
tags: [panorama, architecture, operations]
created: 2026-10-03
updated: 2026-10-05
sources: [panorama-repository.md, rammpeter.github.io.md, rammpeter.github.io/]
---

# Panorama configuration

The settings a [Panorama](../usage/panorama.md) server instance reads at start, where they come from
and what each one does internally. The operator's view — Docker, HTTPS — is in
[Panorama operations](../usage/panorama-operations.md).

## Summary

All settings are resolved once, in `config/application.rb`, in this order
([Panorama source repository](../sources/panorama-source-code.md)):

1. built-in default
2. YAML file named by `PANORAMA_CONFIG_FILE` (since 2.19.2, changelog 2025-11-12)
3. environment variable of the same name — **wins over the file**

Each resolved value is printed at start; anything with `PASSWORD` in its name is
masked. Keys in the file are case-insensitive. A missing file aborts the start.

## The settings

| Setting | Default | Effect |
|---|---|---|
| `PANORAMA_VAR_HOME` | `<tmpdir>/Panorama` | Directory for everything persistent: client info store, generated `secret_key_base`, `Usage.log`, predefined dragnet file. With the default, saved logins and the sampler configuration do not survive a restart reliably — the log and the login dialog both warn |
| `PANORAMA_MASTER_PASSWORD` | none | Enables the admin menu and the sampler. Also the encryption salt of the stored sampler credentials → [Panorama Sampler internals](panorama-sampler-internals.md) |
| `MAX_CONNECTION_POOL_SIZE` | 100 | Upper bound of pooled Oracle sessions **and** of Puma threads → [PanoramaConnection](panorama-connection.md) |
| `PANORAMA_LOG_LEVEL` | `info` in production, `debug` otherwise | Rails log level |
| `PANORAMA_LOG_SQL` | `false` | Additionally logs every SQL statement to stdout |
| `PANORAMA_USAGE_INFO_MAX_AGE` | 180 | Retention of `Usage.log`; `0` disables usage logging |
| `SECRET_KEY_BASE` / `SECRET_KEY_BASE_FILE` | generated | → [Client state and security in Panorama](panorama-client-state-and-security.md) |
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
[Blog series on Panorama as a tool](../sources/blog-panorama-the-tool.md) (2019-03-27), reproduced in [Panorama operations](../usage/panorama-operations.md),
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
  external pages parse them ([Building, testing and releasing Panorama](panorama-build-test-and-release.md))

## What the website says about the settings

([Panorama's website on GitHub Pages](../sources/rammpeter-github-io.md), landing page.) The user-facing documentation lists ten
settings: `MAX_CONNECTION_POOL_SIZE`, `MAX_JAVA_HEAP_SPACE_MB`,
`PANORAMA_CONFIG_FILE`, `PANORAMA_LOG_LEVEL`, `PANORAMA_LOG_SQL`,
`PANORAMA_MASTER_PASSWORD`, `PANORAMA_USAGE_INFO_MAX_AGE`, `PANORAMA_VAR_HOME`,
`SECRET_KEY_BASE`, `SECRET_KEY_BASE_FILE`. It agrees with the table above on the
defaults (pool 100, heap 1024, log level info) and adds intent:

- The config file is **the preferred method**, to keep secrets out of
  environment variables. `PANORAMA_CONFIG_FILE` itself and
  `MAX_JAVA_HEAP_SPACE_MB` work only as environment variables.
- `MAX_CONNECTION_POOL_SIZE` is explained from the user's side: up to that many
  connections are cached "even if they are inactive", and at most that many
  client requests are served concurrently.
- `PANORAMA_USAGE_INFO_MAX_AGE` is a number of **days**, and exists "to comply
  with european GDPR rules".
- `PANORAMA_LOG_SQL=true` is recommended over `PANORAMA_LOG_LEVEL=debug` for
  learning the SQL behind a view — the debug level "logs the same + much more".
  (The 2024 talk recommended the debug level, see [Panorama](../usage/panorama.md).)
- 4096 MB heap is suggested for multi-user production use.

Settings in the table above that the website does not mention are not part of
the documented interface.

## Relationships

- Part of [Panorama architecture](panorama-architecture.md).
- Operator's view: [Panorama operations](../usage/panorama-operations.md).

## Open questions

- ~~Is there user-facing documentation of `PANORAMA_CONFIG_FILE` with an example
  file? The repository's `README.md` does not mention it.~~ Answered
  2026-10-05: the landing page of the website documents it with an example
  ([Panorama's website on GitHub Pages](../sources/rammpeter-github-io.md)) → [Panorama operations](../usage/panorama-operations.md).
- ~~`PANORAMA_USAGE_INFO_MAX_AGE` has no unit in the code that reads it; days are
  likely but unverified.~~ Answered 2026-10-05: the website says "maximum age in
  days".

## Sources

- [Panorama source repository](../sources/panorama-source-code.md)
- [Blog series on Panorama as a tool](../sources/blog-panorama-the-tool.md) (the older variable names)
- [Panorama's website on GitHub Pages](../sources/rammpeter-github-io.md)
