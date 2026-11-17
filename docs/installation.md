# Installation

Zonari is a window-management layer for Hyprland, with an optional Omarchy shell integration. It does not require Omarchy for the core, GTK UI or title bars. Alpha: live validation is currently on Omarchy/Arch with Hyprland 0.56.2; the 0.57.2 title bars have build validation. Other distributions have not been tested.

## Source and layout

Clone the repository:

```sh
git clone https://github.com/lhenr1que/Zonari.git Zonari
cd Zonari
```

The root Cargo workspace builds `crates/zonari-ui/`. `src/core/` contains Lua modules, `src/bars/` the 0.57 plugin, `src/bars-0.56/` the 0.56.2 variant. `omarchy/` contains only the shell integration. Configuration examples belong to `examples/`, Arch recipes and hooks to `packaging/`, executable development/install tools to `scripts/`, shell tests to `tests/`, and documentation to `docs/`. Lua and C++ unit tests remain alongside their modules.

## Omarchy

From the committed checkout cloned above:

```sh
omarchy plugin add "$PWD" --enable
~/.config/omarchy/plugins/zonari/omarchy/zonari setup
hyprctl reload
hyprctl configerrors
```

This uses manifest ID `zonari`. Local changes must be committed before `plugin add`. You can also install directly with `omarchy plugin add https://github.com/lhenr1que/Zonari --enable`. Setup manages the widget, generated config and optional Alt+Tab replacement. Disable it in settings or with the installed wrapper's `alt-tab off`, then reload. Remove using its `remove` command followed by `omarchy plugin remove zonari --yes`.

## Other distributions: source installation

Requirements: Bash/coreutils, Rust/Cargo, a C++23 compiler and make, pkg-config, Hyprland **with its Lua configuration API**, and headers matching the exact running compositor build. The installer accepts 0.56.2 and 0.57.x; future versions require a compatibility review. Matching the version number alone cannot establish plugin ABI compatibility between distro-patched builds.

Development dependencies must expose these pkg-config modules: `hyprland`, `gtk4`, `gtk4-layer-shell-0`, `cairo`, `librsvg-2.0`, `pixman-1`, `libdrm`, `libinput`, `libudev`, `wayland-server`, `xkbcommon`. Install your distribution's runtime and development packages providing them. Package names vary; some distributions need a separate Hyprland development package. No automatic dependency installation is performed.

```sh
bash scripts/install.sh                 # default prefix: ~/.local
# or: bash scripts/install.sh --prefix /absolute/writable/prefix
```

Add the prefix's `bin` directory to PATH. Review the generated `~/.local/share/zonari/zonari.lua`, then copy it to a new file `~/.config/hypr/zonari.lua` (back up any existing file). Load it after your other settings with `require("hypr.zonari")` in `hyprland.lua`, following your distribution's Lua module search path. The example includes absolute paths, so custom prefixes work too. It loads the title-bar plugin; disable conflicting title-bar plugins before activation. Keep a way to restart Hyprland if a native plugin fails.

The example leaves the Alt+Tab switcher disabled. To enable it, unbind your existing pair, enable `switcher.setup()`, and pass `switcher = switcher` to `binds.install`. Review all default bindings for conflicts before loading. The UI starts on the next Hyprland start; start `zonari-ui` manually once for the current session.

```sh
hyprctl reload
hyprctl configerrors
hyprctl plugin list
```

App minimum sizes still apply: narrow zones can overlap neighbouring zones. This does not override an application's minimum width.

### Rebuild and removal

Before upgrading/reinstalling into a loaded plugin path, unload that plugin (or leave the graphical session). After updating Hyprland, rebuild against matching headers with the same installer and prefix, then load the rebuilt plugin and reload the config. A source install has no automatic package-manager rebuild hook.

To remove, first remove the `require` line and reload Hyprland, unload the plugin at `<prefix>/lib/zonari/zonari-bars.so`, and stop `zonari-ui`. Remove only the installer-owned `<prefix>/bin/zonari-ui`, `<prefix>/lib/zonari/`, `<prefix>/share/zonari/` and `<prefix>/share/licenses/zonari/`. Keep `~/.config/zonari/` if you want to retain settings. The installer does not provide an automatic uninstaller and does not own your Hyprland config.

## Arch packages

Recipes are in `packaging/PKGBUILD` and `packaging/bars/PKGBUILD`. Build them with makepkg; set `ZONARI_SRC` to an absolute local clone to build unpublished commits. UI output comes from the root Cargo workspace. These recipes currently target 0.57+; use the source installer or Omarchy setup for 0.56.2. The bars package includes a pacman rebuild hook. No AUR publication or package installation on other machines has been validated.
