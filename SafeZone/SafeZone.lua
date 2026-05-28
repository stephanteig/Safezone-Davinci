-- SafeZone — map to a keyboard shortcut in Workspace > Keyboard Customization.
-- Opens the SafeZone floating GUI. Blocks until the window is closed.
-- See SafeZone_Toggle.lua and SafeZone_Render.lua for headless shortcuts.

local _info = debug.getinfo(1, "S")
local _root = _info.source:sub(2):match("^(.+)/[^/]+%.lua$")
package.path = _root .. "/lib/?.lua;" .. package.path

local ui = require("ui")
ui.open()
