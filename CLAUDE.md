# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Panorama** is a web-based Oracle database performance analysis tool built with Rails 8 on JRuby 10. It is distributed as a standalone executable JAR (`Panorama.jar`) and as a Docker image. The app connects directly to Oracle databases at runtime — there are no migrations and no persistent local database.

## Runtime Requirements

- **JRuby 10.0.3.0** (requires Java 21+); use `chruby` or `ruby-install` to switch versions
- **Java 21+** (for development and running the app)
- Oracle database accessible for real tests (see test env vars below)

## Common Commands

### Development server
```bash
bundle exec rails server
# App runs at http://localhost:3000
```

### Run all tests
```bash
bundle exec rake test
# or
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

### Compile assets
```bash
bundle exec rake assets:precompile
```

### Build the distributable JAR
```bash
./build_jar.sh
# Produces Panorama.jar — requires jarbler gem installed
```

### Security scan
```bash
bundle exec brakeman
```

## Test Configuration

Tests require a live Oracle database. Configure via environment variables:

| Variable | Purpose |
|---|---|
| `TEST_HOST` / `TEST_PORT` / `TEST_SERVICENAME` | Oracle connection |
| `TEST_TNS` | TNS alias (alternative to host/port/service) |
| `TEST_USERNAME` / `TEST_PASSWORD` | DB credentials |
| `TEST_SYSPASSWORD` | SYS password (for privilege tests) |
| `MANAGEMENT_PACK_LICENSE` | `dtp`, `dp`, `ps`, or `none` |
| `DB_VERSION` | Oracle version (10.2, 11, 12, 19, 21, 23) |

Without a real Oracle DB, tests using `connect_oracle_db` will fail. Model/unit tests that don't need a DB connection can run without it.

## Architecture

### Database Connectivity

There is **no static database**. `config/database.yml` uses the `nulldb` adapter. All Oracle connections are established at request time by `ApplicationController` based on session parameters, and managed by `PanoramaConnection` (`app/models/panorama_connection.rb`). Connection parameters live in `Thread.current[:panorama_connection_connect_info]`.

Key patterns in `PanoramaConnection`:
- `sql_execute` / `exec_query` — direct SQL execution
- `iterate_query` — cursor-based streaming for large result sets (avoids loading full results into memory)
- `sql_select_first_row` / `sql_select_all` — convenience wrappers available in controllers and tests via helpers

### Routing

Routes are generated dynamically at boot time (`config/routes.rb`). Every public action in every controller is routed as both `GET` and `POST` at `controller_name/action_name`. There is no RESTful resource routing.

### Controller Pattern

Controllers contain large amounts of direct SQL against Oracle system views (`DBA_*`, `V$*`, `GV$*`). Each controller corresponds to a functional domain:

| Controller | Domain |
|---|---|
| `dba_controller` | Core DBA features |
| `dba_history_controller` | AWR/historical analysis |
| `dba_schema_controller` | Schema objects |
| `dba_sga_controller` | SGA / shared pool / SQL |
| `storage_controller` | Storage and tablespaces |
| `active_session_history_controller` | ASH / wait events |
| `env_controller` | Login, connection, environment |
| `dragnet_controller` | Automated diagnostics |
| `panorama_sampler_controller` | Background data collection |

### Management Pack Licensing

Oracle Management Pack features require a license. The app checks `management_pack_license` (`:diagnostics_pack`, `:diagnostics_and_tuning_pack`, `:panorama_sampler`, or `:none`) before executing licensed queries. Tests must set this via `MANAGEMENT_PACK_LICENSE` and use `assert_response_success_or_management_pack_violation` to handle expected failures.

### Asset Pipeline

Uses Sprockets (not Webpacker/esbuild). SCSS for stylesheets. Assets are compiled to `public/assets/` for production/JAR distribution and removed afterward.

### Configuration

Application behavior is controlled by environment variables (or a config file via `PANORAMA_CONFIG_FILE`):

| Variable | Purpose |
|---|---|
| `MAX_CONNECTION_POOL_SIZE` | Puma thread count / connection pool size |
| `PANORAMA_LOG_LEVEL` | Log verbosity |
| `PANORAMA_VAR_HOME` | Directory for persistent data |
| `PANORAMA_MASTER_PASSWORD` | Password for admin features |

Version and release date are defined as constants in `config/application.rb` (`Panorama::VERSION`, `Panorama::RELEASE_DATE`).

### JAR Distribution

The app is packaged as a self-contained JAR using [jarbler](https://github.com/rammpeter/jarbler). Configuration is in `config/jarble.rb`. Oracle JDBC drivers are bundled in `lib/` (`ojdbc8.jar`, `ojdbc11.jar`, `ojdbc17.jar`). The JAR starts a Puma server on port 8080.

### Browser / System Tests

System tests use **Playwright** (`playwright-ruby-client` gem) via `PlaywrightSystemTestCase` rather than Selenium. CI tests against multiple Oracle versions (10.2 through 23c) and multiple management pack licenses.
