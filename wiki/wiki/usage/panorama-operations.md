---
title: Panorama operations
type: entity
subtype: component
status: draft
tags: [panorama, operations]
created: 2026-10-01
updated: 2026-10-05
sources: [blog.md, posts/, panorama-repository.md, rammpeter.github.io.md, rammpeter.github.io/]
---

# Panorama operations

How [Panorama](panorama.md) is run: as a Docker container, behind a reverse proxy for
HTTPS, and what it takes to connect to an Autonomous Database.

## Docker

([Blog series on Panorama as a tool](../sources/blog-panorama-the-tool.md), 2017-01-29) Available on Docker Hub since January
2017:

```bash
docker pull rammpeter/panorama
docker run --name panorama -p8080:8080 -d rammpeter/panorama
```

Relevant environment variables, as they appear in the 2019 compose example:
`TNS_ADMIN`, `TZ`, `MAX_JAVA_HEAP_SPACE_MB`, `PANORAMA_VAR_HOME`,
`PANORAMA_SAMPLER_MASTER_PASSWORD`, `LOG_LEVEL`. `PANORAMA_VAR_HOME` is mounted
as a volume — persistent data lives there, including the global dragnet
extensions, see [Dragnet Investigation](dragnet.md).

> **Names have changed since 2019** ([Panorama source repository](../sources/panorama-source-code.md)): the code reads
> `PANORAMA_MASTER_PASSWORD` (the old `PANORAMA_SAMPLER_MASTER_PASSWORD` is still
> accepted) and `PANORAMA_LOG_LEVEL` (`LOG_LEVEL` is no longer read). Current
> list of settings: [Panorama configuration](../development/panorama-configuration.md).

## As a JAR

([Panorama source repository](../sources/panorama-source-code.md), `README.md`) Java 21 or higher, then:

```bash
java -jar Panorama.jar
```

The server listens on port 8080. Settings are passed as environment variables or
in a YAML file named by `PANORAMA_CONFIG_FILE` ([Panorama configuration](../development/panorama-configuration.md)).
Without `PANORAMA_VAR_HOME`, saved logins live in a temporary directory.

## HTTPS via a reverse proxy

([Blog series on Panorama as a tool](../sources/blog-panorama-the-tool.md), 2019-03-27) The container does **not** support
HTTPS natively. The route goes via a reverse proxy — in the example Nginx, placed
in front of Panorama using `docker-compose`.

The essential points of the Nginx configuration:

- Port 80 is redirected to HTTPS with a `301`; `/` is redirected to `/Panorama`.
- `proxy_pass` to `http://panorama:8080/Panorama`.
- **The headers are not optional:** `proxy_set_header Host $host` is there with
  the comment that otherwise you get
  `HTTP Origin header didn't match request.base_url` — an error that would be
  hard to interpret without this hint. Plus the usual series `X-Forwarded-For`,
  `-Proto`, `-Ssl`, `-Port`, `-Host`, `X-Real-IP`.
- `proxy_read_timeout 3600`, on the grounds that Panorama handles timeouts
  itself.

**A practical note on certificates:** the author uses his own SSL certificates
and gives the reason — Let's Encrypt "often doesn't work in company environments
behind firewalls".

> **Possibly outdated (2026-10-03):** in the current code the application is
> served at `/`, and `/Panorama` only redirects there (`config/routes.rb`). The
> 2019 example's `proxy_pass …/Panorama` and the redirect of `/` to `/Panorama`
> describe an older layout. Not tested against a current release.

Even without HTTPS, passwords are encrypted in the browser before transfer since
2.19.2 — everything else is not
→ [Client state and security in Panorama](../development/panorama-client-state-and-security.md).

## Autonomous Database in the Oracle Cloud

([Blog series on Panorama as a tool](../sources/blog-panorama-the-tool.md), 2019-09-20) The environment variable `TNS_ADMIN`
must point to a directory containing:

- the `tnsnames.ora` provided by the Oracle Cloud
- the unzipped files of the Oracle wallet: `ewallet.sso`, `ewallet.p12`
- the Java KeyStore files: `truststore.jks`, `keystore.jks`
- `ojdbc.properties` with the connection properties for wallet or KeyStore

> The JKS files are the part that does not follow from Oracle's documentation
> alone: Panorama runs on JRuby and therefore needs the Java route, not the
> native client's.

## From the website

([Panorama's website on GitHub Pages](../sources/rammpeter-github-io.md), landing page.) The current operating instructions; where
they differ from the 2019 examples above, these are newer.

**Starting.** Either `java -jar Panorama.jar` or
`docker run -p 8080:8080 -d rammpeter/panorama`. Start-up takes "some seconds up
to a minute" (one or two minutes for the container); the server is ready when
the console shows `* Listening on http://[::]:8080`.

**Command-line options of the JAR:** `-p` / `--port <port>` (default 8080) and
`-b` / `--bind <IP address>` (default 0.0.0.0).

**Configuration** by a YAML file or by environment variables — the file is "the
preferred method to avoid the compromise of secrets in environemnt variables".
Its location is given by `PANORAMA_CONFIG_FILE`, which itself works only as an
environment variable. All settings: [Panorama configuration](../development/panorama-configuration.md). The website's
example:

```yaml
# /var/opt/panorama/config.yml
PANORAMA_LOG_SQL: "true"
PANORAMA_VAR_HOME: /var/opt/panorama
SECRET_KEY_BASE: 923863l82g2j4797h87g13451v4s589es27g...
```

```bash
PANORAMA_CONFIG_FILE=/var/opt/panorama/config.yml java -jar Panorama.jar -p 8080

docker run --name panorama -p 8080:8080 \
  -v $TNS_ADMIN/tnsnames.ora:/etc/tnsnames.ora \
  -v /var/opt/panorama:/var/opt/panorama \
  -e TNS_ADMIN=/etc -e TZ="Europe/Berlin" \
  -e MAX_JAVA_HEAP_SPACE_MB=1024 \
  -e PANORAMA_CONFIG_FILE=/var/opt/panorama/config.yml -d rammpeter/panorama
```

**Memory.** Default heap 1024 MB; **4096 MB is suggested for multi-user
production use**. `MAX_JAVA_HEAP_SPACE_MB` works for the container only; for the
JAR use Java's own `-Xmx4096m`.

**Container specifics.**

- Mount the host's `tnsnames.ora` and set `TNS_ADMIN` inside the container.
  Caution from the website: with Docker on Windows you sometimes have to mount
  with `-v $TNS_ADMIN/tnsnames.ora:/etc` instead.
- Mount `/var/opt/panorama` to a directory outside the container, so that the
  configuration survives a rebuild.
- The container's time zone is UTC by default; set it with `-e TZ=…`.

**Do set `PANORAMA_VAR_HOME`.** Without it the system's temporary folder holds
the generated encryption key *and* the saved encrypted logins — "this
information may be lost at OS or container restart"
([Client state and security in Panorama](../development/panorama-client-state-and-security.md)).

**`tnsnames.ora` without a container** is expected in
`$ORACLE_HOME/network/admin` or in the directory `TNS_ADMIN` points to. The
diagram `Panorama_Overview.png` (viewed) shows the layout: web clients reach the
Panorama application by http/https, the application reads `tnsnames.ora` on its
own machine and talks SQL*Net to the database — clients need no Oracle
connectivity of their own.

**HTTPS** is still recommended through a reverse proxy (Nginx, Apache, Traefik),
with a link to the 2019 post described above.

**Demo installation.** A public Panorama at <http://158.101.168.240:8080> with a
demo database in the Oracle cloud: TNS aliases `PANORAMATEST_xxx`, user
`panorama_test`, password `TryItOut2019`, as published on the landing page.

**Looking at the server itself.** `http://<server>:8080/usage/connection_pool`
shows the pooled connections ([PanoramaConnection](../development/panorama-connection.md)); with admin login there
are the menu entries "DB connection pool", "Usage history" and "Set log level"
([Panorama menu overview](panorama-menu-overview.md)).

## Relationships

- Runs [Panorama](panorama.md); the sampler data lives under `PANORAMA_VAR_HOME`
  → [Panorama Sampler](panorama-sampler.md).
- Another tool in the blog operated via Docker: [HammerDB](hammerdb.md).
- Cloud environments hold surprises → [LOGON trigger](logon-trigger.md),
  [Unified audit trail – operations](unified-audit-trail-operations.md).
- Which database user to connect with: [Privileges for Panorama](panorama-privileges.md).

## Open questions

- The Nginx and compose examples are from 2019 (`version: '3'`,
  `ssl_protocols TLSv1.1 TLSv1.2`). TLS 1.1 is now considered obsolete — a
  current version is not evidenced in the ingested sources.
- ~~How is Panorama run as a JAR rather than as a container?~~ Answered
  2026-10-03, see *As a JAR*.
- Does the 2019 Nginx example still work unchanged, given that the application
  now lives at `/`?

## Sources

- [Blog series on Panorama as a tool](../sources/blog-panorama-the-tool.md)
- [Panorama source repository](../sources/panorama-source-code.md)
- [Panorama's website on GitHub Pages](../sources/rammpeter-github-io.md)
