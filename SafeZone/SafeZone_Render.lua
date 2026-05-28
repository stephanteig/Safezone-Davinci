-- SafeZone_Render — optional keyboard shortcut for safe-render workflow.
-- Disables all __SZ_* overlay clips, then navigates to the Deliver page.
-- Equivalent to clicking "Safe Render" in the GUI (Phase 3).
-- §7.22: if render is started via a native Resolve shortcut while the GUI is closed,
--        this script offers no protection — see README.md for documentation.

local _info = debug.getinfo(1, "S")
local _root = _info.source:sub(2):match("^(.+)/[^/]+%.lua$")
package.path = _root .. "/lib/?.lua;" .. package.path

local core    = require("core")
local overlay = require("overlay")

-- Disable all overlays. §7.21: no-op (and not an error) if no overlays are active.
local ok, err = overlay.set_enabled(false)
if not ok then
    print("[SafeZone] Warning: could not disable overlays: " .. tostring(err))
    -- Continue to Deliver anyway — user chose this path.
end

local resolve, res_err = core.get_resolve()
if not resolve then
    print("[SafeZone] Render failed: " .. tostring(res_err))
    return
end

local page_ok = resolve:OpenPage("deliver")
if not page_ok then
    print("[SafeZone] OpenPage('deliver') returned false")
end
