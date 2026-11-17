# Architecture

Zonari runs inside an existing Hyprland session. Hyprland remains the compositor and executes window operations; Zonari provides window-management policies and UI.

| Component | Responsibility |
|---|---|
| `src/core/` | Lua policy: geometry, snapping, zones, rules, workspace modes, window actions and switcher state |
| `crates/zonari-ui/` | GTK4/layer-shell views: settings, layouts, Snap Assist, switcher, menus and fallback bars |
| `src/bars/` | Native title bars, drag previews and input integration for Hyprland 0.57 |
| `src/bars-0.56/` | Native title bars for Hyprland 0.56.2 |
| `omarchy/` | Optional shell widget and install/configuration wrapper |

The Lua core loads with the Hyprland configuration. Native bars and GTK views request actions through `hyprctl eval` and `hl.plugin.zonari`. Runtime JSON files communicate switcher and Snap Assist state to the views. User settings and layouts live under `$XDG_CONFIG_HOME/zonari` (default `~/.config/zonari`).

The native plugin is bound to an exact compositor ABI. Rebuild after Hyprland changes. The UI can draw fallback layer-shell bars, which have different stacking and animation limits from native decorations.

Restore geometry is partly transient and may be lost on config reload. A client application's minimum size takes precedence over a zone's requested size. Workspace policy and cross-monitor behavior need testing for each supported compositor version; a successful build is not a live-session validation.
