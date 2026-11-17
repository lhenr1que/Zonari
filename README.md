# Zonari

> Formerly *OmniWM*, *HyperVi* and, before that, *Kwinish*. Everything now carries the Zonari name:
>
> | Before | Now |
> |---|---|
> | Lua module `kwinish`, `hl.plugin.kwinish`, options `plugin:kwinish:*` | `zonari`, `hl.plugin.zonari`, `plugin:zonari:*` |
> | `~/.config/omniwm/` or `~/.config/kwinish/` (settings, layouts, rules) | `~/.config/zonari/` (copied once by `omarchy/zonari setup`) |
> | `kwinish-ui`, `kwinish-bars.so`, window tags `kwinish-*` | `zonari-ui`, `zonari-bars.so`, `zonari-*` |
> | Omarchy plugin `hypervi`, `~/.config/hypr/hypervi.lua` | `zonari`, `~/.config/hypr/zonari.lua` |
>
> Dated records (`docs/history`, `docs/port-0-57`, `docs/STATUS.md`, `docs/DEVELOPMENT_STATE.md`, `openspec/`) keep the names of their time.

KWin-style window management for **Hyprland 0.56.2 and 0.57.x** with Lua configuration. **Alpha**: live-tested on Omarchy/Arch 0.56.2; the 0.57.2 plugin has build validation. Other distributions can build from source when matching Hyprland APIs, headers and dependencies are available; they have not been tested. Native plugins must be rebuilt for the exact Hyprland build.

Start with the [documentation index](docs/README.md), [implemented architecture](docs/ARCHITECTURE.md) and [current status](docs/STATUS.md). The [product documentation](docs/product/README.md) describes the future suite; approval of a product decision does not imply implementation.

Three cooperating layers; the Lua core owns window-management policy, and the UI and plugin provide its surfaces:

| Layer | What | Needs |
|---|---|---|
| `zonari-core/` (Lua) | Tiling/Scroll/Floating workspace policies, rules, quick tile/zones, one-axis maximize, pack to edge, show desktop, keep above, placement, auto-raise, hot corners, Alt+Tab logic and binds | Hyprland with a Lua config |
| `zonari-ui/` (Rust, `zonari-ui`) | Alt+Tab overlay, window menu, layout picker/editor, Snap Assist, settings, shortcut dialog and fallback title bars | GTK4, gtk4-layer-shell |
| `zonari-bars/` (C++, `zonari-bars`) | the title bar: a compositor plugin forked from hyprbars | Hyprland headers, librsvg; rebuilt for each Hyprland update |

## Title bars

The plugin is the primary bar: app icon, pin button and title on the left; minimize, maximize and close on the right; drawn
by the compositor, so stacking, animations, borders and rounding are the real ones. Right click opens the window menu,
double click maximizes, the wheel over the bar raises or lowers the window, and dropping a dragged window on the left or
right screen edge snaps it to a half, and on the top edge maximizes it (`snap_top_edge`, on by default). Dragging across the seam between two monitors takes an extra push of `seam_resistance` pixels (default 200, 0 turns it off). Bars show on every window; `floating_only`
limits them to floating ones.

**Snap preview and layouts.** While a window is dragged by its bar, a translucent rectangle shows where releasing it on a screen edge will put it. Holding **Shift** shows every zone of the active tiling layout (two columns, three columns, 2x2 grid, main and side, wide centre) and releasing snaps the window into the zone under the pointer. Pick the layout with `zonari-ui layouts` (`SUPER + T`) or in the window menu. Make your own with the zone editor (`zonari-ui zones`, `SUPER + CTRL + E`, or "Edit zones..." in the picker): split, add floating blocks, set the padding, load a preset to start from; layouts are saved in `~/.config/zonari/layouts.json` and show up in the picker. Dragging a snapped window by its bar gives back its old size.

**Settings.** `zonari-ui settings` (or "Zonari settings..." under More actions in the window menu) opens a window with the title-bar, colour and snapping options (and the Snap Assist switch). Changes apply at once and are kept in `~/.config/zonari/settings.json`, which the core applies on every config load; options you never touch there keep coming from your Hyprland config.

**Window menu.** KWin-style, born from the bar: click the app icon or right-click the bar. Workspaces, maximize, minimize, keep above or below, fullscreen, no frame, hide from captures, snap, tiling layout, close. State shows as check marks.

A plugin is locked to one Hyprland build, so after a Hyprland update the plugin can be stale. Then Zonari runs in
**emergency mode**: it does not load the plugin, shows a notification, and `zonari-ui bars` draws fallback bars
(layer-shell surfaces that sit above all windows, so they hide or clip when another window covers them). The pacman hook
in the plugin package rebuilds the plugin after `hyprland` changes; or run `sudo zonari-bars-rebuild`. Details in
[plugin operations](docs/PLUGIN.md).

## Install

Full instructions, dependencies, activation, rebuild and removal: [installation guide](docs/INSTALL.md).

```sh
git clone --branch omarchy-plugin-0.57.2 https://github.com/lhenr1que/HyperVi.git Zonari
cd Zonari
```

**Omarchy plugin:** the root `manifest.json` exposes a bar widget; setup selects the correct title-bar source and manages a generated Hyprland Lua module. Alt+Tab replacement is optional and can be disabled in settings.

```sh
omarchy plugin add "$PWD" --enable
~/.config/omarchy/plugins/zonari/omarchy/zonari setup
hyprctl reload
hyprctl configerrors
```

**Other Hyprland distributions:** build and install without Omarchy. The installer leaves configuration and the running session untouched; follow the [activation instructions](docs/INSTALL.md) after reviewing the generated Lua example.

```sh
bash scripts/install.sh --prefix "$HOME/.local"
```

Both routes need headers matching the compositor and the Hyprland Lua API. On Omarchy, bindings use `SUPER + CTRL + ALT` (arrows for halves; U/I/J/K for corners). Independent installs use the defaults below; review conflicts first. Arch package recipes are in `resources/packaging/` and currently target 0.57+; no packages are published to AUR.

Default binds with the default `mod = "SUPER"` ([table](zonari-core/binds.lua), installed by `resources/recipes/hyprland-snippet.lua`):
`SUPER + ALT + arrows` halves/top/bottom; `SUPER + ALT + Q/W/A/S` corners; `SUPER + ALT + Return` maximize;
`SUPER + ALT + H/V` one axis; `SUPER + CTRL + ALT + arrows` pack; `SUPER + D` show desktop;
`SUPER + ALT + T` keep above; `SUPER + T` layout picker; `SUPER + CTRL + E` zone editor.
The recipe also enables `ALT + Tab` and `ALT + F3` (window menu). Check local conflicts and use `mod`/`override`.

## Tests
```
bash scripts/check.sh
```
One command for every Lua suite, the tool tests, the Rust tests and a plugin build, in a temporary HOME; it exits non-zero
on any failure. `--lua-only` runs just the Lua suites. The same command runs in CI on Arch Linux (`.github/workflows/check.yml`). Details: [testing guide](docs/TESTING.md). Tests that need a live session are scripted for a person to run, with their results, in [STATUS](docs/STATUS.md).

## Development records
Changes go through [OpenSpec](openspec/) (proposals, designs, tasks and the accepted specs). `docs/STATUS.md`, `docs/DEVELOPMENT_STATE.md`, `docs/port-0-57/` and `docs/history/` are the author's working records: dated, kept as they were, and written for the author's machine (absolute paths in the live test scripts are deliberate). Most project documentation is in Portuguese.

## Known limits
- Restore geometry lives in a Lua table and is lost on a zonari-core/config reload. Show-desktop origins, keep-above and keep-below are kept in window tags and survive it; this does not make every state reload-safe.
- Title-bar drag ends through the compositor: if another client grabs input exactly on release, the drag continues until the next key or click (accepted for the alpha). Touch on the bar is off.
- The fallback bars are layer-shell surfaces: not at window level, and they trail animated windows by up to 80 ms.
- Recorded tests include two monitors, but cross-monitor drops, workspace modes on the second monitor and non-default scale/rotation still have pending scenarios. XWayland-only setups and a real Hyprland package upgrade are not established as validated.

## License
MIT, see `LICENSE`. `zonari-bars/` is a fork of hyprbars (BSD 3-Clause, `zonari-bars/LICENSE.hyprland-plugins`, `zonari-bars/NOTICE`).

Applications retain their minimum window size. If a zone is narrower (for example OpenBot in a one-third zone), Zonari keeps the minimum width and positions the window within the screen; it may overlap a neighbouring zone.
