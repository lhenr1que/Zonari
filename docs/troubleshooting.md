# Troubleshooting

## No title bars or drag zones

Check `hyprctl configerrors` and `hyprctl plugin list`. Both the native title-bar plugin and the Lua core must be loaded. The plugin alone cannot implement snap policies, Shift-drag zones or menu actions. Disable other title-bar plugins to avoid duplicate decorations.

## Plugin fails after a Hyprland upgrade

Native plugins must match the exact compositor build. Rebuild using the same install route; see [installation](installation.md). Omarchy installations provide `omarchy/zonari status` and `rebuild`. Do not load a stale plugin just because its file exists.

## Window does not fit a zone

Applications can enforce a minimum size. OpenBot, for example, was measured at a 960-pixel minimum width. Use a wider zone or two columns. Zonari preserves the minimum width and keeps the window inside the screen, so it may overlap an adjacent zone.

## Shortcuts conflict

Omarchy setup maps window actions to `SUPER + CTRL + ALT`. Inspect registered shortcuts with `hyprctl binds`. Standalone examples use different defaults; review them before activation. Alt+Tab replacement is optional. On Omarchy, disable it in settings or run the installed wrapper's `alt-tab off` and reload Hyprland.

## Settings or layouts are missing

User data belongs in `~/.config/zonari`. Omarchy setup copies old OmniWM/Kwinish configuration once, preferring OmniWM, and preserves the original directories. Back up settings before editing or migrating them manually.

## Validation limits

Live testing has been performed on Omarchy/Arch with Hyprland 0.56.2. The 0.57.2 plugin has build validation. Other distributions, every scale/rotation combination, a real package upgrade and every reload/login scenario have not been validated.
