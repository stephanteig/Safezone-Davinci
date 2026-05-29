local M = {}

local overlay = require("overlay")
local core    = require("core")

-- Module-level timer reference so M.stop() can reach it.
local _timer     = nil
local _last_page = nil

-- Shows a modal-style dialog when the user navigates to Deliver with overlays enabled.
-- Uses a nested disp:RunLoop() — standard Fusion UI Manager pattern for blocking dialogs.
-- on_disable_cb: called only if the user chooses "Disable & Continue".
local function show_guard_dialog(disp, ui_mgr, on_disable_cb)
    local dlg = disp:AddWindow({
        ID           = "SafeZoneGuardDlg",
        WindowTitle  = "SafeZone — Overlay Active",
        Geometry     = { 150, 150, 480, 120 },
        Spacing      = 8,
        Margin       = 14,

        ui_mgr:VGroup{
            ui_mgr:Label{
                Text      = "An overlay is active. Rendering now will bake it into the output.",
                Alignment = { AlignHCenter = true },
            },
            ui_mgr:HGroup{
                ui_mgr:Button{ ID = "btn_guard_disable", Text = "Disable & Continue"          },
                ui_mgr:Button{ ID = "btn_guard_keep",    Text = "Keep Overlay (will render)"  },
            },
        },
    })

    -- §7.20: default to "keep" so dismissing via X is a no-op (safest default = don't change state)
    local choice = "keep"

    dlg.On.btn_guard_disable.Clicked = function(ev)
        choice = "disable"
        disp:ExitLoop()
    end

    dlg.On.btn_guard_keep.Clicked = function(ev)
        disp:ExitLoop()
    end

    -- §7.20: X button → treat as "Keep Overlay"
    dlg.On.SafeZoneGuardDlg.Close = function(ev)
        disp:ExitLoop()
    end

    dlg:Show()
    disp:RunLoop()  -- nested loop — outer RunLoop is suspended until ExitLoop() is called
    dlg:Hide()

    if choice == "disable" then
        overlay.set_enabled(false)
        if on_disable_cb then on_disable_cb() end
    end
end

-- Starts the page-polling guard timer.
-- disp          — the UIDispatcher from ui.lua (needed to create the dialog window)
-- on_disable_cb — called with no args when the user chooses "Disable & Continue";
--                 use this to refresh the main window's status/footer labels
function M.start(disp, on_disable_cb)
    local ui_mgr = fu.UIManager  -- fu is auto-injected by Resolve; guard.start() is only
                                  -- called from inside M.open() which already validates fu

    -- Stop any previous timer before starting a new one (handles rapid re-launches).
    if _timer then
        _timer:Stop()
        _timer = nil
    end

    -- Capture the current page so the first tick doesn't false-fire on an existing Deliver page.
    local resolve, _ = core.get_resolve()
    _last_page = resolve and resolve:GetCurrentPage() or nil

    _timer = ui_mgr:Timer{ Interval = 500 }

    _timer.On.Timeout = function()
        local res, _ = core.get_resolve()
        if not res then return end  -- Resolve unavailable — skip tick silently

        local page = res:GetCurrentPage()
        if not page then return end  -- §4 caveat: GetCurrentPage() can return nil

        if page == "deliver" and _last_page ~= "deliver" then
            if overlay.any_enabled() then
                _timer:Stop()  -- pause polling while dialog is open
                show_guard_dialog(disp, ui_mgr, on_disable_cb)
                _timer:Start()  -- resume after dialog closes
            end
        end

        _last_page = page
    end

    _timer:Start()
end

-- Stops the guard timer. Must be called in the main window's close handler.
-- §12 anti-pattern: every Start() needs a Stop() in the close handler.
function M.stop()
    if _timer then
        _timer:Stop()
        _timer = nil
    end
    _last_page = nil
end

return M
