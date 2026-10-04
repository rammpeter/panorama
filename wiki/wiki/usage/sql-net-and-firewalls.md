---
title: SQL*Net and firewalls
type: concept
status: draft
tags: [network, session, oracle]
created: 2026-10-01
updated: 2026-10-02
sources: [blog.md, posts/]
---

# SQL*Net and firewalls

Firewalls terminate idle TCP sessions, often after about an hour. For a
long-running query that is fatal — and the failure shows up in the most
inconvenient place.

## The damage pattern

([[blog-sessions-and-connections]], 2017-06-12) While a long SQL or PL/SQL
program runs, the TCP connection is *apparently* idle. If the firewall terminates
it:

- The database cannot send the result. After the TCP timeout is reached, the
  server terminates the database session.
- **The client stays in a socket read forever**, waiting for a response that
  never comes.

No error, no exception — a hanging process.

## Oracle's full solution: SQLNET.EXPIRE_TIME

The parameter `SQLNET.EXPIRE_TIME=x` in the `sqlnet.ora` sends a keep-alive
packet on idle connections every *x* minutes and thereby stops the firewall from
considering them dead.

**Where it belongs — and where it has no effect:**

| Location | Effect |
|---|---|
| `sqlnet.ora` of the **RDBMS** `ORACLE_HOME` (usually `$ORACLE_HOME/network/admin`) | **works** |
| `sqlnet.ora` of the Grid Infrastructure | none |
| `sqlnet.ora` of the **client** | none |

**How large the value may be:** smaller than **half** the firewall's idle
timeout. The reason from the source: the keep-alive packets subsequently follow
exactly at the stated interval — but the **first** one is sent within a range of
up to *twice* the stated time. Common value: `SQLNET.EXPIRE_TIME=10`.

## Oracle's lightweight solution: enable=broken

In the client's `tnsnames.ora`:

```
net_service_name=(DESCRIPTION=(enable=broken)(ADDRESS=...
```

Creates **no** keep-alive packets. Instead, terminated TCP sessions are detected
and re-established from the client side.

> Drawing that distinction is this post's actual contribution:
> `enable=broken` keeps the idle connection functional but does **not** ensure
> that you still receive the result of a long-running query. It is therefore *not*
> an equivalent substitute for `SQLNET.EXPIRE_TIME`.

## Verifying

Keep-alive packets are real TCP packets within the session and therefore visible
with `tcpdump`. The post supplies a shell script (Linux and macOS, to be run as
root) that establishes an idle session via `DBMS_LOCK.SLEEP`, determines the
client port and database host via `lsof`, and then captures for 4000 seconds — so
you either see the packets or you do not.

## Relationships

- The opposite direction of the same topic: [[network-latency-from-ash]] measures
  what the network costs while the connection stands.
- Related to [[short-lived-sessions]] — both are problems of the connection layer
  that [[ash]] does not see.

## Open questions

- Why does the parameter have no effect in the Grid Infrastructure
  `sqlnet.ora`? The source states it but does not explain it.
- Is there by now a solution that also rescues the result of the long query?
  Neither of the described routes does that.

## Sources

- [[blog-sessions-and-connections]]
