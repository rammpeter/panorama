---
title: Controllers, routing and rendering in Panorama
type: concept
status: draft
tags: [panorama, architecture, gui]
created: 2026-10-03
updated: 2026-10-03
sources: [panorama-repository.md]
---

# Controllers, routing and rendering in Panorama

The pattern every feature of [Panorama](../usage/panorama.md) follows: a controller action runs SQL,
a partial describes the columns, a generic grid renders the rows, and the result
is an HTML fragment injected into the page by AJAX. Knowing this pattern is most
of what is needed to add a view.

## Summary

Panorama is a single page that never reloads. The start page renders the frame
and the menu; from then on every click requests a fragment and names the `div`
it should replace. The user-visible traits listed in [Panorama](../usage/panorama.md) — every cell a
link, every table a chart, drill-down that keeps the previous level on screen —
all follow from this ([Panorama source repository](../sources/panorama-source-code.md)).

## Routing by convention

`config/routes.rb` does not list routes. At boot it calls
`EnvController.routing_actions`, which **reads the controller source files as
text**: for each `class` line it derives the controller name, and each `def`
line becomes a route `controller/action` until a line `private` is seen.
Excluded are names containing `?` and `self.` methods.

Each action gets a `GET` and a `POST` route, except those in
`EnvController::POST_ONLY_ACTIONS` → [Route state-changing actions as POST only](route-state-changing-actions-post-only.md).

Consequences worth knowing:

- A new public method in a controller is reachable immediately. A helper method
  that must not be callable has to sit below `private`.
- The parser is line-based and knows only `public` and `private`. A `protected`
  line does not end the public section, so the scan also emits routes for the
  protected methods of `ApplicationController`. They lead nowhere: Rails itself
  dispatches only to public methods.
- There are no named routes and no REST resources.

## Anatomy of an action

A typical read-only action (`dba_controller.rb`, `show_redologs`):

```ruby
def show_redologs
  @instance = prepare_param_instance
  @redologs = sql_select_iterator("SELECT … FROM gV$LOG …")
  render_partial
end
```

- **Parameters** are fetched with `prepare_param`, `prepare_param_int`,
  `prepare_param_instance`, `prepare_param_dbid`, which normalise empty values.
- **Time ranges** go through `save_session_time_selection`, which validates the
  format and remembers the range for the next dialog.
- **SQL** is built as a string. Conditions on optional parameters are appended
  to a `where` string with their values in a parallel array, then passed as
  `[sql, *binds]` ([PanoramaConnection](panorama-connection.md)).
- **Version differences** are handled inline:
  `#{"…" if get_db_version >= '11.1'}`. `PanoramaConnection.rac?`, `.is_cdb?`
  and `dba_or_cdb(view)` serve the same purpose ([Pluggable databases](../usage/pluggable-databases.md)).
- **`render_partial`** renders `_<action>.html.erb` of the same controller.
  Status-bar and popup messages collected during the action are appended as a
  small script.

## The grid generator

Nearly every partial ends in one call:

```erb
<%= gen_slickgrid(@rows, column_options, {caption: "…", max_height: 450}) %>
```

`column_options` is an array of hashes. The important keys
(`app/helpers/slickgrid_helper.rb`):

| Key | Meaning |
|---|---|
| `caption`, `title` | header text and mouse-over explanation |
| `data` | a `proc { \|rec\| … }` producing the cell — plain value or a link helper |
| `align`, `data_style`, `css_class` | presentation; `data_style` as a proc is how conspicuous values get their colour |
| `plot_master`, `plot_master_time` | marks the column that becomes the x-axis when the table is turned into a chart |
| `show_pct_col_sum_background` | draws the cell's share of the column total as a fill level |
| `field_decorator_function` | JavaScript body for client-side cell rendering |

Global options include `caption`, `max_height`, `context_menu_entries`,
`command_menu_entries`, `show_pin_icon` and `update_area`.

The generator emits the rows as a JavaScript data structure plus a call into
`slickgrid_extended.js` (1,700 lines), which adds sorting, filtering, column
sums, export, the context menu and the "show as diagram" function (flot) on top
of SlickGrid. That is why **every table can become a chart** without the view
author doing anything beyond marking the x-axis column.

Rows may come from `sql_select_iterator`, in which case they are streamed from
the cursor straight into the generated output.

## Links and the update area

Cells become links through helpers in `ajax_helper.rb`: generic ones
(`ajax_link`, `ajax_form`, `ajax_submit`) and domain ones
(`link_sql_id`, `link_session_details`, `link_object_description`,
`link_historic_sql_id`, `link_wait_params` …). Using the domain helpers is what
makes the same SQL ID lead to the same detail page from anywhere.

Each link names an `update_area` — the `div` to fill. Views obtain fresh ids from
`get_unique_area_id` and place an empty `div` below the grid; the detail fragment
lands there. Drill-down thus **appends** below the current level instead of
replacing it. A pinned grid (`show_pin_icon`) is protected from being
overwritten when its parent refreshes.

The request parameters of any fragment can be copied to the clipboard and
replayed later ("Execute with given parameters") — possible precisely because a
view is fully described by controller, action and parameters.

## The menu

`MenuHelper#menu_content` is one nested Ruby array: `menu` nodes with `content`,
`item` leaves with `controller`, `action`, `caption`, `hint`. Optional keys
`min_db_version` and `condition` hide entries that the connected database does
not support (`menu_content_for_db`); Exadata and ASM entries, for instance, are
shown only if the corresponding views return rows.

If an `item` names an action that the controller does not define, the request is
served by `EnvController#render_menu_action`, which just renders the partial of
that name — the usual case for entries that first show a parameter form.

A test helper walks this same structure and calls every menu entry of the
controller under test ([Building, testing and releasing Panorama](panorama-build-test-and-release.md)).

## The dragnet catalogue

[Dragnet Investigation](../usage/dragnet.md) is data, not code paths. `DragnetHelper#dragnet_sql_list` assembles a
tree from 26 helper modules in `app/helpers/dragnet/`. A leaf is a hash:

| Key | Meaning |
|---|---|
| `name`, `desc` | title and explanation (translated via `t`) |
| `sql` | the statement, with `?` placeholders |
| `parameter` | array of `{name, title, size, default}` — the input fields |
| `min_db_version` | hides the entry on older databases |
| `plsql` | execute as anonymous PL/SQL returning JSON through `DBMS_OUTPUT` |
| `not_executable`, `suppress_error_for_code` | special cases |

There are roughly 150 SQL entries under eight top-level groups. Two further
branches are appended at runtime: the entries from
`PANORAMA_VAR_HOME/predefined_dragnet_selections.json`, and the personal entries
from the client info store.

An entry is addressed by its **position path** in the tree (`_0_1_3`); entries
have no stable identifier of their own.

> Conclusion: the numbers users see ("point 2.6") can only be those positions,
> so they shift whenever an entry is inserted before another. References to
> dragnet points by number — as in the blog — are reliable only for the release
> they were written against.

Dragnet statements pass the [Pack licence filter](pack-license-filter.md) like any other SQL.

## Assets

Sprockets, no Node build for the application code (Node is needed only by the
JavaScript minifier during precompilation). Third-party libraries are checked in
under `vendor/assets/`. Texts are English by default with German translations in
`config/locales`; the default text sits inline at the call site
(`t(:key, default: '…')`).

## Relationships

- Part of [Panorama architecture](panorama-architecture.md).
- Data access: [PanoramaConnection](panorama-connection.md); licence check: [Pack licence filter](pack-license-filter.md).
- Why inline scripts constrain the content security policy:
  [Client state and security in Panorama](panorama-client-state-and-security.md).

## Open questions

- The route scanner and Rails disagree about what is public (`protected`
  methods get a route but are not dispatched). Harmless as read, but two
  definitions of "public action" exist — is that intended?
- Is there a convention for when SQL belongs in the controller and when in a
  helper? Both occur.
- The JavaScript side (`slickgrid_extended.js`, `plot_diagram.js`,
  `dashboard.js`) was not read.

## Sources

- [Panorama source repository](../sources/panorama-source-code.md)
