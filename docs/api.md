# Integration API

The integration surface is experimental and may change. Hyprland's Lua API is required.

## Lua core

Load `src/core/` through `package.path`, then `require("zonari")`. Common functions:

| Function | Purpose |
|---|---|
| `setup(opts)` | Initialize policy; supports placement, auto-raise and reserved screen areas |
| `window_action(addr, action)` | Request an action for a Hyprland window address |
| `tile(where)`, `maximize_axis(axis)`, `pack(dir)` | Arrange the selected window |
| `layout_names()`, `set_layout(name)` | Query/select zone layouts |
| `show_desktop()`, `keep_above()`, `keep_below()` | Window visibility and stacking |
| `menu()`, `layouts()`, `zone_editor()` | Open UI views |
| `set_workspace_mode(ws, mode)` | Set a workspace's tiling, scrolling or floating mode |
| `set_scrolling_columns(ws, n)` | Set one to three visible columns |

`window_action` accepts actions including `tile:<where>`, `zone:<n>`, `layout:<name>`, `axis:<h|v>`, `pack:<dir>`, `above`, `below`, `float`, `fullscreen`, `maximize`, `minimize`, `pin`, `close`, `workspace:<n|new>`, `grab:<move|resize>`, `rule:<name>`, `mode:<name>`, `columns:<n>`, `noframe` and `nocapture`. Zone/tile actions accept an optional `@monitor-name` suffix. Grab actions require native plugin support.

## Native plugin

Lua namespace: `hl.plugin.zonari`. Configuration namespace: `plugin:zonari:*`.

Plugin entry points include `add_button`, `set_zone`, `clear_zones`, `set_bar_hidden`, `grab`, `remember` and `forget`. Calls to `grab` can fail if the window cannot be focused or a drag cannot start; UI code should handle errors.

## Files and UI

User data is stored under `$XDG_CONFIG_HOME/zonari` (default `~/.config/zonari`). Runtime JSON for the switcher and Snap Assist is published under `$XDG_RUNTIME_DIR/zonari`. Treat these files as internal, transient data.

The `zonari-ui` executable provides settings, layouts, zones, menu, switcher, assist and fallback-bar views. Running it without a subcommand starts the daemon used by the overlays. Native plugin ABI receipts identify the matching compositor build and must not be edited to force compatibility.
