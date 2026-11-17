-- Runs a generated hypervi.lua with stub hl/modules and prints the final bind keys (core/binds.lua list + override),
-- one per line, normalized (modifiers sorted, upper case). Used by tools/test-omarchy-plugin.sh.
local file, core = arg[1], arg[2]
package.path = core .. "/?.lua;" .. package.path
local real = dofile(core .. "/binds.lua")
local captured
local noop = setmetatable({}, { __index = function() return function() end end })
package.preload["binds"] = function() return { install = function(_, o) captured = o end } end
package.preload["kwinish"] = function() return noop end
package.preload["switcher"] = function() return noop end
hl = setmetatable({ plugin = {} }, { __index = function() return function() end end })
dofile(file)
assert(captured, "hypervi.lua did not call binds.install")
local function norm(k)
  local mods, rest = {}, {}
  for raw in k:gmatch("[^+]+") do
    local p = raw:gsub("^%s+", ""):gsub("%s+$", ""):upper() -- Lua 5.5: loop variables are constant
    if p == "SUPER" or p == "CTRL" or p == "ALT" or p == "SHIFT" then mods[#mods + 1] = p else rest[#rest + 1] = p end
  end
  table.sort(mods)
  local seen, m = {}, {}
  for _, x in ipairs(mods) do if not seen[x] then seen[x] = true; m[#m + 1] = x end end
  return table.concat(m, "+") .. "+" .. table.concat(rest, "+")
end
for _, b in ipairs(real.list(captured.mod)) do
  local k = b.keys
  if captured.override and captured.override[k] ~= nil then k = captured.override[k] end
  if k then print(b.action .. ":" .. (b.arg or "") .. "=" .. norm(k)) end
end
