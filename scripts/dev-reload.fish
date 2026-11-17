#!/usr/bin/env fish
# Dev loop: load this checkout's plugin and Lua core into the running Hyprland.
# Reloading the plugin brings back the installed core (/usr/share/zonari), which ignores the plugin's "@monitor" actions
# and snaps nothing, so both must be reloaded together.
set root (path resolve (status dirname)/..)
hyprctl plugin unload $root/src/bars/zonari-bars.so
hyprctl plugin load $root/src/bars/zonari-bars.so
hyprctl eval "package.path='$root/src/core/?.lua;'..package.path; for _,m in ipairs({'zonari','geometry','layouts','assist','rules','modes','binds','switcher','settings','kwjson'}) do package.loaded[m]=nil end; require('zonari')"
