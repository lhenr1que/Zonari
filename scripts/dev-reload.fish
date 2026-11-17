#!/usr/bin/env fish
# Dev loop: load this checkout's plugin and Lua core into the running Hyprland.
# Reloading the plugin brings back the installed core (/usr/share/omniwm), which ignores the plugin's "@monitor" actions
# and snaps nothing, so both must be reloaded together.
set root (path resolve (status dirname)/..)
hyprctl plugin unload $root/omniwm-bars/omniwm-bars.so
hyprctl plugin load $root/omniwm-bars/omniwm-bars.so
hyprctl eval "package.path='$root/omniwm-core/?.lua;'..package.path; for _,m in ipairs({'omniwm','geometry','layouts','assist','rules','modes','binds','switcher','settings','kwjson'}) do package.loaded[m]=nil end; require('omniwm')"
