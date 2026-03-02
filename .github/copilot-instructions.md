# Panorama – Copilot Instructions

Panorama is a Ruby on Rails 8.0.4 / JRuby web application for Oracle database performance analysis. It runs as a self-contained Java JAR or Docker container. It does **not** use ActiveRecord for querying Oracle data — all database interaction goes through a custom connection wrapper.

## Build & Test Commands

```bash
# Start development server
bundle exec rails server

# Run the full test suite (requires a live Oracle DB — see env vars below)
bundle exec rails test

# Run a single test file
bundle exec ruby test/controllers/dba_controller_test.rb

# Run tests matching a glob
bundle exec rake test TEST="test/controllers/dba*_test.rb"

# Security scan (uses config/brakeman.ignore for known false positives)
bundle exec brakeman --ignore-config config/brakeman.ignore

# Build distributable JAR
./build_jar.sh

# Build Docker image
./create_docker_image.sh
```

**Required test environment variables:**

| Variable | Example | Notes |
|---|---|---|
| `TEST_USERNAME` | `panorama_test` | Oracle user |
| `TEST_PASSWORD` | `panorama_test` | |
| `TEST_PORT` | `1521` | |
| `TEST_SERVICENAME` | `ORCLPDB1` | |
| `MANAGEMENT_PACK_LICENSE` | `diagnostics_and_tuning_pack` | Also: `diagnostics_pack`, `panorama_sampler`, `none` |
| `PANORAMA_VAR_HOME` | `/tmp/panorama_var` | Writable runtime state directory |

## Architecture

### Dynamic Routing

Routes are **not** declared statically. `config/routes.rb` calls `EnvController.routing_actions()` at boot, which reflects over every controller and auto-registers `GET` and `POST` routes for every public action as `controller_name/action_name`. There are no named routes or RESTful resource conventions. When adding a new action to any controller it is automatically routed — no routes.rb change is needed.

### Request Lifecycle

```
Browser (AJAX) → ApplicationController#begin_request
                    → validates browser_tab_id param
                    → establishes Oracle connection via PanoramaConnection
               → Controller action
                    → delegates all business logic to paired Helper module
               → ERB partial
                    → rendered as HTML fragment injected into a DOM update area
```

Almost all responses are partial HTML fragments. The calling JavaScript passes an `update_area` param identifying the DOM element to replace. Full-page renders only happen on initial load.

### Business Logic Lives in Helpers

Controllers are thin. All Oracle queries and data processing live in `app/helpers/`, which pair 1:1 with controllers (e.g. `DbaController` includes `DbaHelper`). Sub-domains are further split into sub-directories:
- `app/helpers/dragnet/` — automated performance issue detection rules
- `app/helpers/panorama_sampler/` — custom data collection helpers

### Oracle Database Access

Never use ActiveRecord query methods for Oracle data. Use these helper wrappers (available everywhere via `ApplicationHelper`):

```ruby
# Returns Array of Hash rows; bind variables via Array syntax
sql_select_all("SELECT col FROM v$Session WHERE sid = :sid", binds: [sid])
sql_select_all(["SELECT col FROM v$Session WHERE sid = ?", sid])  # positional

sql_select_first_row(sql)       # → first row Hash or nil
sql_select_one(sql)             # → scalar value
sql_select_iterator(sql) { |row| ... }  # streaming; avoids loading full result into memory
```

All query results are plain `Hash` objects extended with `SelectHashHelper`, so columns are accessible both as methods (`rec.column_name`) and via `[]` with String or Symbol keys.

### UI Data Tables (SlickGrid)

All tabular output uses SlickGrid. Every data ERB partial follows this pattern:

```erb
<%
column_options = [
  { caption: "Name",  data: proc { |rec| rec.object_name }, title: "Tooltip" },
  { caption: "Size",  data: proc { |rec| fn(rec.bytes) },   title: "Bytes", align: :right },
]
%>
<%= gen_slickgrid(@result_set, column_options, { caption: "Table title" }) %>
```

`fn(value)` is the standard locale-aware number formatter. Use it for any numeric column. `data:` must be a `Proc` (preferred) or a String expression that will be `eval`'d with `rec` in scope.

### Per-User Session State

User state is stored in `ClientInfoStore` — a file-backed store keyed by an encrypted browser cookie (`client_key`) combined with `browser_tab_id`. This allows multiple independent browser tabs per user. Do **not** use Rails `session[]` or controller instance variables for cross-request state. Access via:

```ruby
read_client_info_store(:key)
write_client_info_store(:key, value)

# Tab-specific (most settings):
ClientInfoStore.read_from_browser_tab_client_info_store(get_decrypted_client_key, @browser_tab_id, :key)
ClientInfoStore.write_to_browser_tab_client_info_store(get_decrypted_client_key, @browser_tab_id, { key: value })
```

## Key Conventions

### Parameter Handling
Use `prepare_param` helpers instead of `params[]` directly — they handle nil/blank and type coercion:

```ruby
prepare_param(:name)                    # → String or nil (strips whitespace)
prepare_param(:name, default: 'all')   # → String with fallback
prepare_param_int(:page)               # → Integer
prepare_param_boolean(:show_all)       # → Boolean
prepare_param_instance                 # → validated RAC instance number
prepare_param_dbid                     # → validated DBID integer
```

### Oracle Version / License Gating
Many features depend on Oracle version or licensed management packs. Always check before accessing restricted views:

```ruby
get_db_version           # → "19.3.0.0.0" (String)
get_db_version_numeric   # → 19.3 (Float, major.minor only)
PanoramaConnection.autonomous_database?
management_pack_license  # → :diagnostics_and_tuning_pack | :diagnostics_pack | :panorama_sampler | :none
PanoramaConnection.rac?
PanoramaConnection.is_cdb?
```

### File Encoding
Every Ruby source file begins with `# encoding: utf-8`.

### Error Handling
- Raise `PopupMessageException` to show a user-facing popup message (not a full error page)
- `ExceptionHelper.reraise_extended_exception(e, "context message")` adds context when re-raising
- `ApplicationController#global_exception_handler` catches all uncaught exceptions and renders `application/_error_message` partial

### Tests
Tests use `ActionDispatch::IntegrationTest`. Requests are made directly by path, not named route helpers:

```ruby
post '/dba/show_redologs', params: { format: :html, update_area: :hugo, instance: 1 }
assert_response :success
```

`set_session_test_db_context` (from `lib/test_helpers/`) establishes the Oracle test connection in `setup`. The helper `call_controllers_menu_entries_with_actions` exercises all menu-accessible actions automatically — every controller test calls it.

### Rails Components Excluded
ActionCable, ActionMailer, ActiveStorage, ActionText are not loaded. Do not add dependencies on them.

### Runtime
- Java 21+ required; JRuby 10.0.3.0 (see `.ruby-version`)
- Oracle JDBC drivers are bundled in `lib/ojdbc*.jar` — no separate install needed
- Key env vars at runtime: `PANORAMA_VAR_HOME` (writable state dir), `PANORAMA_MASTER_PASSWORD` (optional encryption key)
