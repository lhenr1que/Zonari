-- Minimal setup. The package installs src/core/ to /usr/share/zonari/core; for a manual install copy it to ~/.local/share/zonari/core.
package.path = os.getenv("HOME") .. "/.local/share/zonari/core/?.lua;/usr/share/zonari/core/?.lua;" .. package.path
local kw = require("zonari")
kw.setup({ placement = "smart", autoraise_ms = 400 }) -- drop either option to turn it off
local sw = require("switcher")
sw.setup()                                             -- Alt+Tab; start the overlay with: exec-once = zonari-ui
require("binds").install(kw, { mod = "SUPER", switcher = sw, menu = "ALT + F3" })        -- pass override = { ["SUPER + D"] = false } to drop a bind
-- Hot corners (optional): dwell 300 ms in a corner. Actions: "show_desktop", "menu", { exec = "cmd" } or a function.
-- kw.hotcorners({ corners = { topright = "show_desktop", bottomleft = { exec = "rofi -show drun" } } })
