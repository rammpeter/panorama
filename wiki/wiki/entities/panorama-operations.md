---
title: Panorama operations
type: entity
subtype: component
status: draft
tags: [panorama, operations]
created: 2026-10-01
updated: 2026-10-02
sources: [blog.md, posts/]
---

# Panorama operations

How [[panorama]] is run: as a Docker container, behind a reverse proxy for
HTTPS, and what it takes to connect to an Autonomous Database.

## Docker

([[blog-panorama-the-tool]], 2017-01-29) Available on Docker Hub since January
2017:

```bash
docker pull rammpeter/panorama
docker run --name panorama -p8080:8080 -d rammpeter/panorama
```

Relevant environment variables, as they appear in the 2019 compose example:
`TNS_ADMIN`, `TZ`, `MAX_JAVA_HEAP_SPACE_MB`, `PANORAMA_VAR_HOME`,
`PANORAMA_SAMPLER_MASTER_PASSWORD`, `LOG_LEVEL`. `PANORAMA_VAR_HOME` is mounted
as a volume — persistent data lives there, including the global dragnet
extensions, see [[dragnet]].

## HTTPS via a reverse proxy

([[blog-panorama-the-tool]], 2019-03-27) The container does **not** support
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

## Autonomous Database in the Oracle Cloud

([[blog-panorama-the-tool]], 2019-09-20) The environment variable `TNS_ADMIN`
must point to a directory containing:

- the `tnsnames.ora` provided by the Oracle Cloud
- the unzipped files of the Oracle wallet: `ewallet.sso`, `ewallet.p12`
- the Java KeyStore files: `truststore.jks`, `keystore.jks`
- `ojdbc.properties` with the connection properties for wallet or KeyStore

> The JKS files are the part that does not follow from Oracle's documentation
> alone: Panorama runs on JRuby and therefore needs the Java route, not the
> native client's.

## Relationships

- Runs [[panorama]]; the sampler data lives under `PANORAMA_VAR_HOME`
  → [[panorama-sampler]].
- Another tool in the blog operated via Docker: [[hammerdb]].
- Cloud environments hold surprises → [[logon-trigger]],
  [[unified-audit-trail-operations]].

## Open questions

- The Nginx and compose examples are from 2019 (`version: '3'`,
  `ssl_protocols TLSv1.1 TLSv1.2`). TLS 1.1 is now considered obsolete — a
  current version is not evidenced in the ingested sources.
- How is Panorama run as a JAR rather than as a container? The repository
  describes it, the blog does not.

## Sources

- [[blog-panorama-the-tool]]
