---
name: panorama-test-runner
description: Run tests for the Panorama Rails/JRuby Oracle database tool. Use this skill whenever the user wants to run tests, execute a test file, run a specific test by name, or asks about test setup, Oracle DB environment variables, or why tests are failing. Always trigger for any mention of "test", "rake test", "rails test", "test_connect", or Oracle test configuration in the Panorama project.
---

# Panorama Test Runner

This skill helps run tests in the Panorama project — a Rails 8 / JRuby 10 app that requires a live Oracle database for most tests.

## Prerequisites

Tests require **JRuby 10.1.0.0** (needs Java 21+). Switch to it with `chruby jruby-10.1.0.0` if needed.

Most tests need a live Oracle database configured via environment variables (see below). Tests that call `connect_oracle_db` will fail without one. Pure model/unit tests can run without a DB.

## Oracle DB environment variables

Set these before running tests that need a database connection:

| Variable | Purpose |
|---|---|
| `TEST_HOST` | Oracle host (use with `TEST_PORT` + `TEST_SERVICENAME`) |
| `TEST_PORT` | Oracle port (default: 1521) |
| `TEST_SERVICENAME` | Oracle service name |
| `TEST_TNS` | TNS alias (alternative to host/port/service) |
| `TEST_USERNAME` | DB username |
| `TEST_PASSWORD` | DB password |
| `TEST_SYSPASSWORD` | SYS password (only needed for privilege tests) |
| `MANAGEMENT_PACK_LICENSE` | `dtp` (Diagnostics+Tuning), `dp` (Diagnostics), `ps` (Panorama Sampler), or `none` |
| `DB_VERSION` | Oracle version: `10.2`, `11`, `12`, `19`, `21`, or `23` |

Export them inline or in your shell profile.

## Commands

### Run all tests
```bash
bundle exec rake test
# or equivalently:
RAILS_ENV=test bundle exec rails test
```

### Run a single test file
```bash
RAILS_ENV=test bundle exec rails test test/controllers/dba_history_controller_test.rb
```

### Run a single test by name
```bash
RAILS_ENV=test bundle exec rails test test/models/panorama_connection_test.rb -n test_connect
```

The `-n` flag accepts a test method name (e.g. `test_connect`) or a regex (e.g. `-n /connect/`).

## Handling management pack failures

Tests for licensed Oracle features (Diagnostics Pack, Tuning Pack) may fail with a management pack violation if `MANAGEMENT_PACK_LICENSE` doesn't match the license on the connected database. Use the helper `assert_response_success_or_management_pack_violation` in tests that exercise licensed queries — this is the expected pattern in Panorama.

## Common failure patterns

- **`connect_oracle_db` fails** → Oracle env vars not set or DB unreachable. Check `TEST_HOST`/`TEST_TNS`, `TEST_USERNAME`, `TEST_PASSWORD`.
- **Wrong Ruby version** → JRuby 10.1.0.0 required. Run `ruby -v` and switch with `chruby`.
- **Asset errors in integration tests** → Run `bundle exec rake assets:precompile` first.
- **Management pack errors** → Set `MANAGEMENT_PACK_LICENSE` to match the DB license, or use `none` to skip licensed tests.
