-- SafeZone_Toggle — map to a keyboard shortcut in Workspace > Keyboard Customization.
-- Toggles the enabled state of all __SZ_* overlay clips on the current timeline.
-- Works headlessly: no GUI required.

local _info = debug.getinfo(1, "S")
local _root = _info.source:sub(2):match("^(.+)/[^/]+%.lua$")
package.path = _root .. "/lib/?.lua;" .. package.path

local core    = require("core")
local overlay = require("overlay")

-- §7.1 / §7.2: give feedback if there's no project/timeline rather than silently no-op
local timeline, tl_err = core.get_timeline()
if not timeline then
    print("[SafeZone] Toggle skipped: " .. tl_err)
    return
end

local ok, err = overlay.toggle()
if not ok then
    print("[SafeZone] Toggle failed: " .. tostring(err))
end
