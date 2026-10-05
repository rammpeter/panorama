---
title: Client state and security in Panorama
type: concept
status: draft
tags: [panorama, architecture, security]
created: 2026-10-03
updated: 2026-10-05
sources: [panorama-repository.md, rammpeter.github.io.md, rammpeter.github.io/]
---

# Client state and security in Panorama

How [[panorama]] remembers who a browser is and which database it is logged in
to, how database passwords are protected, and which defences the web layer has.

## Summary

Panorama has no user accounts. Identity is a random key in a browser cookie;
authorisation is whatever the Oracle user behind the stored login may read. The
security design therefore has one main asset to protect — database credentials —
and one administrative secret, the master password
([[panorama-source-code]]).

## Identifying a client

Two cookies, both `httponly`, renewed for one year on each visit
(`app/helpers/env_helper.rb`):

- **`client_salt`** — a random value.
- **`client_key`** — a random number, stored **encrypted** with a key built from
  the salt and the server's `secret_key_base`.

The decrypted client key is the lookup key into the server-side store. A third
element, **`browser_tab_id`**, is not a cookie but a request parameter assigned
when the start page loads; it lets two tabs of one browser be connected to
different databases. Every request must carry it.

## The client info store

`ClientInfoStore` (`app/models/client_info_store.rb`) is a singleton around
`ActiveSupport::Cache::FileStore` in `PANORAMA_VAR_HOME/client_info.store`.

Per client key it holds, among other things: locale, the list of last logins,
the last time selection, personal dragnet SQL ([[dragnet]]), and per browser tab
the **current database** (connect info, chosen licence, chosen DBID, sampler
schema) and the last menu action used.

The Rails session cookie carries almost nothing; the start page actively deletes
legacy keys from it. Its lifetime — 8 hours after the last request
(`MAX_SESSION_LIFETIME_AFTER_LAST_REQUEST`) — matters because it carries the
CSRF token.

Housekeeping runs hourly with `ConnectionTerminateJob`: tab entries without a
request for 8 hours are dropped, client entries unused for 12 months are deleted.

> Conclusion: because the state is on disk, a server restart does not log users
> out — provided `PANORAMA_VAR_HOME` and the `secret_key_base` survive the
> restart. If either is lost, saved logins become undecryptable. The start-up
> log warns when `PANORAMA_VAR_HOME` points to a temporary directory.

## Password protection

**In transit.** Even without HTTPS, passwords are not sent in clear text
(changelog 2025-11-11). `Encryption` generates a 2048-bit RSA key pair **in
memory at process start**. The page receives the public key; the browser
encrypts the password with RSA-OAEP using the `forge` library; the server
decrypts with the private key that never leaves the process. This applies to
database passwords and to the master password.

**At rest.** The password is stored in the client info store encrypted by
`ActiveSupport::MessageEncryptor` with the key `client_salt + secret_key_base`.
Half of the key is thus on the client, half on the server: the store alone, or
the cookie alone, does not yield the password.

**In use.** It is decrypted per JDBC login from the thread's connect info. The
pool compares password hashes before reusing a connection
([[panorama-connection]]).

> This is no substitute for HTTPS: everything else — SQL texts, results — still
> travels unencrypted without it. For HTTPS see [[panorama-operations]].

## The secret key base

`config/initializers/create_secrets.rb` resolves it in this order:

1. `SECRET_KEY_BASE` from environment or config file
2. the file named by `SECRET_KEY_BASE_FILE`
3. `PANORAMA_VAR_HOME/secret_key_base`, if it exists
4. otherwise a new random value, written to that file

A warning is logged if the secret is shorter than 128 characters.

## Administrative functions

The admin menu and the sampler configuration require the **master password**
(`PANORAMA_MASTER_PASSWORD`). Without one configured, those functions do not
exist. `AdminController#admin_logon`:

- compares with `secure_compare`, to leak nothing through timing;
- on success issues a JWT (HS256, signed with `client_salt + secret_key_base`)
  as an `httponly` cookie valid for 8 hours;
- throttles failures per client: three free attempts, then an exponentially
  growing delay capped at 300 seconds. The throttle rejects the attempt outright
  instead of sleeping, so it cannot be used to tie up server threads (changelog
  2026-09-01).

## Web-layer defences

- **CSRF.** `protect_from_forgery with: :exception`. An invalid token raises and
  is shown as "session expired" rather than silently resetting the session.
  Because Rails checks the token only on non-GET requests, state-changing
  actions have no GET route → [[route-state-changing-actions-post-only]].
- **Parameter screening.** Every request parameter, name and value, is
  normalised (entities unescaped, HTML comments removed, whitespace stripped,
  upper-cased) and rejected if it contains one of a list of tags (`<SCRIPT`,
  `<IMG`, `<IFRAME`, `<SVG` …) or an inline event handler pattern.
- **Framing.** The content security policy sets `frame-ancestors 'none'`.
- **Cookies** use `SameSite=Lax`.
- **Static analysis.** Brakeman runs in CI
  ([[panorama-build-test-and-release]]).

## What is deliberately not protected

- **The SQL itself.** Panorama's purpose is to run queries with the user's own
  database privileges, including a free SQL worksheet. Protection against
  harmful SQL is the database's privilege system, not Panorama. Many controller
  actions interpolate request parameters into SQL text; that is injection only in
  the sense that the user could have typed the same statement into the worksheet.
- **Script CSP.** `script-src` is not restricted: the rendering model depends on
  inline scripts in fragments ([[panorama-request-and-rendering]]). The
  initializer lists the steps to change that as TODOs.

> Conclusion: the trust boundary is the Oracle login. Anyone who can reach a
> Panorama instance can attempt logins to any database that instance can reach
> on the network — Panorama adds no access control in front of that.

## The website's account of the same model

([[rammpeter-github-io]], landing page, "What about security?".) The
user-facing description agrees with what the code shows and is worth having in
the author's words:

- Credentials are "always asynchronously encrypted at network transfer from
  browser to the Panorama server by a public key", even without HTTPS —
  asymmetric encryption is meant.
- The database password is stored encrypted on the server and decrypted "shortly
  in server memory only for the process of establishing connection".
- The key is the server-side `SECRET_KEY_BASE` **salted with a client key from
  the browser cookie** — "this way only requests from your browser are able to
  reuse the stored connect info".
- Logins saved with the checkbox "Save logins" are stored under
  `PANORAMA_VAR_HOME`, encrypted the same way.
- The key "can contain all printable characters and should be at least 128
  characters long". **Every change of the key invalidates all stored connection
  info.** Without a fixed key a generated one is stored under
  `PANORAMA_VAR_HOME`.
- The sampler's connection passwords are encrypted "with a combination of server
  key … and your master password" (sampler page).

**What is logged about users.** `Usage.log` under `PANORAMA_VAR_HOME` is plain
text and records client IP address, database name, time, called function and
the TNS alias or URL. `PANORAMA_USAGE_INFO_MAX_AGE = 0` disables it; with admin
login it can be viewed under "Admin" / "Usage history".

## Relationships

- Part of [[panorama-architecture]].
- Feeds the connect info of [[panorama-connection]].
- Stores the configuration of [[panorama-sampler-internals]].
- Settings: [[panorama-configuration]].

## Open questions

- The client key is a random number below ten million. Is its confidentiality
  relied upon anywhere, or only the encryption wrapped around it?
- The RSA key pair is regenerated at each start. What happens to a login form
  that was loaded before a restart and submitted after it?

## Sources

- [[panorama-source-code]]
- [[rammpeter-github-io]]
