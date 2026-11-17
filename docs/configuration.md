# Configuration

User settings, layouts and rules live under `$XDG_CONFIG_HOME/zonari` (default `~/.config/zonari`). Use the settings UI where possible:

```sh
zonari-ui settings
zonari-ui layouts
zonari-ui zones
```

## User files

| File | Purpose |
|---|---|
| `settings.json` | Appearance and behavior preferences |
| `layouts.json` | User-defined zones |
| `layout` | Selected layout |
| `rules.json` | Window rules |
| `shortcuts.json` | Shortcut overrides |
| `workspace-modes.json` | Per-workspace policy |
| `workspace-columns.json` | Scrolling column counts |

Settings are parsed as data, never executed as Lua. Back up files before manual edits. See the source modules in `src/core/` for the current JSON readers and validation rules.

## Title-bar settings

The native plugin uses `plugin:zonari:*`; Lua configuration is passed through `hl.config({ plugin = { zonari = { ... } } })`.

| Group | Settings |
|---|---|
| Visibility | `enabled`, `floating_only`, `bar_title_enabled`, `show_icon` |
| Geometry | `bar_height`, `bar_part_of_window`, `bar_precedence_over_border`, `bar_padding` |
| Text | `bar_text_size`, `bar_text_weight`, `bar_text_font`, `bar_text_align` |
| Colors | `bar_color`, `inactive_bar_color`, `col.text`, `inactive_col.text`, `button_hover_color`, `pinned_color`, `preview_color` |
| Buttons | `default_buttons`, `bar_buttons_alignment`, `bar_button_padding`, `icon_on_hover`, `on_double_click` |
| Snapping | `snap_top_edge`, `snap_preview`, `seam_resistance` |

The settings UI stores persistent overrides in `settings.json`. Core-only preferences include `snap_assist`, `alt_tab` and `workspace_modes`. On Omarchy, workspace mode controls are left to Omarchy's workspace indicator and omitted from Zonari's menu.

## Shortcuts

Omarchy uses `SUPER + CTRL + ALT`:

| Key | Action |
|---|---|
| Arrow keys | Snap to halves |
| U / I / J / K | Snap to corners |
| Return | Maximize |
| H / V | Maximize one axis |
| M | Show desktop |
| P | Keep above |
| L | Layout picker |
| Shift + arrow keys | Pack to edge |

The Omarchy zone editor is `SUPER + CTRL + SHIFT + L`. `ALT + F3` opens the window menu. Alt+Tab replacement is optional and can be disabled in the settings UI or with the installed wrapper's `alt-tab off` followed by `hyprctl reload`.

Standalone examples use the defaults in `src/core/binds.lua`: `SUPER + ALT + arrows` for halves, Q/W/A/S for corners, and `SUPER + T` for the layout picker. Review conflicts before installing bindings. `binds.install` accepts overrides; assigning `false` drops a binding.

## Geometry and persistence

Zones account for gaps, borders and title bars. Applications retain their minimum size and can exceed narrow zones. Geometry restoration has transient Lua state and may be lost on config reload; do not assume all window state survives a reload.
