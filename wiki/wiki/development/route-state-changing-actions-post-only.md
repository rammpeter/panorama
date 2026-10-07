---
title: Route state-changing actions as POST only
type: decision
decision_status: adopted
status: draft
tags: [panorama, architecture, security]
created: 2026-10-03
updated: 2026-10-03
sources: [panorama-repository.md]
---

# Route state-changing actions as POST only

**Status: adopted.** Actions of [Panorama](../usage/panorama.md) that change state get no `GET`
route. Everything else keeps both `GET` and `POST`.

## The choice

Routes are generated for every public controller method
([Controllers, routing and rendering in Panorama](panorama-request-and-rendering.md)). Since release 2.19.25, the generator skips
the `GET` route for actions listed in `EnvController::POST_ONLY_ACTIONS`:

| Controller | Actions |
|---|---|
| `addition` | SQL worksheet: execute, explain, remember binds and last SQL ID |
| `admin` | logon, logout, set log level |
| `dba` | optimizer parse trace |
| `dba_sga` | SQL Tuning Advisor: run, drop task, create profile |
| `dragnet` | add and drop personal selection |
| `env` | login, choice of licence, DBID and sampler schema, locale, client settings |
| `panorama_sampler` | save, delete, import configuration; clear error |

## The rationale

From the comment above the list and the changelog entry:

> "Rails does not verify the CSRF token for GET requests, so such an action must
> not be reachable by GET, otherwise it could be triggered by a crafted link
> from a foreign site." — `env_controller.rb`

> "Security: Route state changing actions as POST only, because Rails does not
> check the CSRF token for GET requests" — `CHANGELOG.md`, 2026-09-01

The GUI already called all of these through `ajax_html` / `ajax_form`, which use
`POST`, so nothing in the interface had to change.

The same release hardened the neighbourhood: an invalid CSRF token now raises
instead of resetting the session, failed master password attempts are throttled
per client, and sampler configuration import and export require admin
authentication ([Client state and security in Panorama](panorama-client-state-and-security.md)).

## Why not POST for everything

> Conclusion (not stated in the source): read-only actions keep their `GET`
> route because being addressable by URL is a feature there — fragments are
> replayed from copied parameters, and Oracle's reports open in a new browser
> tab by URL. Restricting only the actions with side effects keeps that.

## Open despite the decision (implementation risks)

- **The list is maintained by hand.** A new action with side effects is
  reachable by `GET` until someone adds it. Nothing in the code or the tests
  enforces completeness.
- **"State-changing" is judged per action.** Several read-style actions execute
  SQL built from parameters. They cannot be forged into changing Panorama's own
  state, but whether any of them can be driven to execute DML or DDL on the
  target database through a crafted `GET` link was not examined.

## Provenance

Changelog entry of 2026-09-01, released as 2.19.25; code as read on 2026-10-03
(commit `d887d8d3`). The decision is documented in the repository itself, not in
a separate design document.

## Sources

- [Panorama source repository](../sources/panorama-source-code.md)
