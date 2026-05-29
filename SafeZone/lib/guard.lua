local M = {}

local overlay = require("overlay")

-- TIMER API NOTE: ui_mgr:Timer{} returns a layout descriptor, not a live event object.
-- Live timer objects require being embedded inside a disp:AddWindow() call and accessed
-- via win.On.timerID.Timeout. The standalone timer approach does not work.
-- Page-poll guard is therefore disabled; protection is via the Safe Render button only.
-- See CLAUDE.md VERIFY items for the outstanding timer API question.

-- Shows a modal-style dialog using a nested disp:RunLoop().
-- on_disable_cb: called only if the user chooses "Disable & Continue".
local function show_guard_dialog(disp, ui_mgr, on_disable_cb)
    local dlg = disp:AddWindow({
        ID          = "SafeZoneGuardDlg",
        WindowTitle = "SafeZone — Overlay Active",
        Geometry    = { 150, 150, 480, 120 },
        Spacing     = 8,
        Margin      = 14,

        ui_mgr:VGroup{
            ui_mgr:Label{
                Text      = "An overlay is active. Rendering now will bake it into the output.",
                Alignment = { AlignHCenter = true },
            },
            ui_mgr:HGroup{
                ui_mgr:Button{ ID = "btn_guard_disable", Text = "Disable & Continue"         },
                ui_mgr:Button{ ID = "btn_guard_keep",    Text = "Keep Overlay (will render)" },
            },
        },
    })

    -- §7.20: default to "keep" so X / dismiss does not change overlay state.
    local choice = "keep"

    dlg.On.btn_guard_disable.Clicked = function(ev)
        choice = "disable"
        disp:ExitLoop()
    end

    dlg.On.btn_guard_keep.Clicked    = function(ev) disp:ExitLoop() end
    dlg.On.SafeZoneGuardDlg.Close    = function(ev) disp:ExitLoop() end

    dlg:Show()
    disp:RunLoop()
    dlg:Hide()

    if choice == "disable" then
        overlay.set_enabled(false)
        if on_disable_cb then on_disable_cb() end
    end
end

-- Exposes the guard dialog so the Safe Render button can invoke it directly.
-- Pass disp (UIDispatcher), ui_mgr (fu.UIManager), and an optional callback.
M.show_dialog = show_guard_dialog

-- start/stop are no-ops — page-poll timer disabled pending API verification.
function M.start(disp, on_disable_cb) end
function M.stop() end

return M
