local M = {}

local overlay = require("overlay")
local detect  = require("detect")
local core    = require("core")
local presets = require("presets")
local guard   = require("guard")

local SINGLETON_KEY    = "SafeZone.IsOpen"
local HIGHLIGHT_MARKER = "\xe2\x97\x86 "  -- UTF-8 ◆ (U+25C6); technical prefix for matched buttons

-- Map of button IDs to preset keys and display text, used for event wiring and highlighting.
-- `text` is the button label as shown in the window (may differ from preset.label, e.g. "X" vs "X / Twitter").
local PLATFORM_BUTTONS = {
    { id = "btn_tiktok",    key = "tiktok_9x16",    text = "TikTok"        },
    { id = "btn_ig_reels",  key = "ig_reels_9x16",  text = "IG Reels"      },
    { id = "btn_yt_shorts", key = "yt_shorts_9x16", text = "YT Shorts"     },
    { id = "btn_ig_feed",   key = "ig_feed_4x5",    text = "IG Feed (4:5)" },
    { id = "btn_ig_post",   key = "ig_post_1x1",    text = "IG Post (1:1)" },
    { id = "btn_yt_16x9",   key = "yt_16x9",        text = "YT (16:9)"     },
    { id = "btn_x_twitter", key = "x_twitter_16x9", text = "X"             },
}

local RATIO_BUTTONS = {
    { id = "btn_r_4x3",  key = "ratio_4x3",  text = "4:3"  },
    { id = "btn_r_9x16", key = "ratio_9x16", text = "9:16" },
    { id = "btn_r_16x9", key = "ratio_16x9", text = "16:9" },
    { id = "btn_r_1x1",  key = "ratio_1x1",  text = "1:1"  },
}

-- All overlay-action button IDs in one list for bulk enable/disable.
local ACTION_BUTTON_IDS = {
    "btn_tiktok", "btn_ig_reels", "btn_yt_shorts",
    "btn_ig_feed", "btn_ig_post", "btn_yt_16x9", "btn_x_twitter",
    "btn_r_4x3", "btn_r_9x16", "btn_r_16x9", "btn_r_1x1",
    "btn_toggle", "btn_remove_all", "btn_render",
}

-- Sets the footer label.
local function set_footer(itms, text)
    itms.footer.Text = text
end

-- Returns a human-readable footer string reflecting current overlay state.
-- §7.8: if clips were manually deleted, find_all() returns {} → "No overlays active".
local function get_overlay_status()
    local clips = overlay.find_all()
    if #clips == 0 then
        return "No overlays active"
    end

    -- Build a name→enabled map from the live timeline clips.
    local name_to_enabled = {}
    for _, item in ipairs(clips) do
        name_to_enabled[item:GetName()] = item:GetClipEnabled()
    end

    -- Match clip names against preset clip_name_prefix to get display labels.
    local labels = {}
    local any_on = false
    for _, p in ipairs(presets.all()) do
        local enabled = name_to_enabled[p.clip_name_prefix]
        if enabled ~= nil then
            labels[#labels + 1] = p.label
            if enabled then any_on = true end
        end
    end

    if #labels == 0 then
        -- Clips exist but none match a known preset (user-renamed, or SetProperty failed).
        return string.format("%d overlay(s) active", #clips)
    end

    local prefix = any_on and "Active: " or "Hidden: "
    return prefix .. table.concat(labels, ", ")
end

-- Applies or removes the ◆ highlight marker on platform and ratio buttons.
-- Buttons whose preset.ratio matches `ratio` get the marker; all others show plain text.
-- When ratio == "unknown" (custom resolution or no timeline) all buttons are plain.
local function update_button_highlights(itms, ratio)
    for _, btn_def in ipairs(PLATFORM_BUTTONS) do
        local p = presets.lookup(btn_def.key)
        if p and ratio ~= "unknown" and p.ratio == ratio then
            itms[btn_def.id].Text = HIGHLIGHT_MARKER .. btn_def.text
        else
            itms[btn_def.id].Text = btn_def.text
        end
    end
    for _, btn_def in ipairs(RATIO_BUTTONS) do
        local p = presets.lookup(btn_def.key)
        if p and ratio ~= "unknown" and p.ratio == ratio then
            itms[btn_def.id].Text = HIGHLIGHT_MARKER .. btn_def.text
        else
            itms[btn_def.id].Text = btn_def.text
        end
    end
end

-- Updates the status label and button enabled state based on current timeline.
-- §7.1 / §7.2: if no timeline, disables all overlay action buttons.
local function refresh_ui(itms)
    local ratio, w, h = detect.detect_ratio()

    local has_timeline = (w ~= nil)  -- detect_ratio returns nil w/h only when no timeline

    if not has_timeline then
        itms.status.Text = "No timeline open"
        for _, id in ipairs(ACTION_BUTTON_IDS) do
            itms[id].Enabled = false
        end
        update_button_highlights(itms, "unknown")
        set_footer(itms, "No overlays active")
    else
        if ratio == "unknown" then
            itms.status.Text = string.format("Custom: %d\xC3\x97%d", w, h)  -- UTF-8 ×
        else
            itms.status.Text = "Detected: " .. ratio:gsub("x", ":")
        end
        for _, id in ipairs(ACTION_BUTTON_IDS) do
            itms[id].Enabled = true
        end
        update_button_highlights(itms, ratio)
        set_footer(itms, get_overlay_status())
    end
end

-- Shows an error in the status label without changing button state.
local function show_error(itms, msg)
    itms.status.Text = "Error: " .. tostring(msg)
end

-- Builds and returns the window definition table.
-- Called inside M.open() after confirming fu and UIManager are available.
local function build_window(ui, disp)
    return disp:AddWindow({
        ID = "SafeZoneWin",
        WindowTitle = "SafeZone",
        Geometry = { 100, 100, 380, 560 },
        Spacing = 6,
        Margin = 12,

        ui:VGroup{
            ID = "root",

            ui:Label{
                ID = "status",
                Text = "Initializing...",
                Alignment = { AlignHCenter = true },
                Font = ui:Font{ PixelSize = 13, Bold = true },
            },

            ui:HGap(0, 8),

            ui:Label{ Text = "Platform" },

            -- Row 1: 9:16 platforms
            ui:HGroup{
                ui:Button{ ID = "btn_tiktok",    Text = "TikTok" },
                ui:Button{ ID = "btn_ig_reels",  Text = "IG Reels" },
                ui:Button{ ID = "btn_yt_shorts", Text = "YT Shorts" },
            },
            -- Row 2: mixed-ratio platforms
            ui:HGroup{
                ui:Button{ ID = "btn_ig_feed",   Text = "IG Feed (4:5)" },
                ui:Button{ ID = "btn_ig_post",   Text = "IG Post (1:1)" },
                ui:Button{ ID = "btn_yt_16x9",   Text = "YT (16:9)" },
                ui:Button{ ID = "btn_x_twitter", Text = "X" },
            },

            ui:HGap(0, 8),

            -- Ratio-only section
            ui:Label{ Text = "Aspect ratio only" },
            ui:HGroup{
                ui:Button{ ID = "btn_r_4x3",  Text = "4:3"  },
                ui:Button{ ID = "btn_r_9x16", Text = "9:16" },
                ui:Button{ ID = "btn_r_16x9", Text = "16:9" },
                ui:Button{ ID = "btn_r_1x1",  Text = "1:1"  },
            },

            ui:HGap(0, 8),

            -- Stack mode checkbox
            ui:HGroup{
                ui:CheckBox{
                    ID      = "stack_mode",
                    Text    = "Stack mode (or Shift+click)",
                    Checked = false,
                },
            },

            ui:HGap(0, 8),

            ui:HGroup{
                ui:Button{ ID = "btn_toggle",     Text = "Toggle overlay" },
                ui:Button{ ID = "btn_remove_all", Text = "Remove all" },
            },
            ui:HGroup{
                ui:Button{
                    ID   = "btn_render",
                    Text = "Safe Render",
                    Font = ui:Font{ Bold = true },
                },
            },

            ui:HGap(0, 4),

            ui:Label{
                ID        = "footer",
                Text      = "No overlays active",
                Alignment = { AlignHCenter = true },
            },
        },
    })
end

-- Wires all event handlers onto the window.
local function wire_events(win, itms, disp)

    -- Platform buttons: mode driven by stack_mode checkbox
    for _, btn_def in ipairs(PLATFORM_BUTTONS) do
        local key = btn_def.key
        win.On[btn_def.id].Clicked = function(ev)
            local mode = itms.stack_mode.Checked and "stack" or "replace"
            local ok, err = overlay.add(key, mode)
            if not ok then
                show_error(itms, err)
            else
                refresh_ui(itms)
            end
        end
    end

    -- Ratio buttons: same pattern as platform buttons
    for _, btn_def in ipairs(RATIO_BUTTONS) do
        local key = btn_def.key
        win.On[btn_def.id].Clicked = function(ev)
            local mode = itms.stack_mode.Checked and "stack" or "replace"
            local ok, err = overlay.add(key, mode)
            if not ok then
                show_error(itms, err)
            else
                refresh_ui(itms)
            end
        end
    end

    win.On.btn_toggle.Clicked = function(ev)
        local ok, err = overlay.toggle()
        if not ok then
            show_error(itms, err)
        else
            set_footer(itms, get_overlay_status())
        end
    end

    win.On.btn_remove_all.Clicked = function(ev)
        local ok, err = overlay.remove_all()
        if not ok then
            show_error(itms, err)
        else
            refresh_ui(itms)
        end
    end

    win.On.btn_render.Clicked = function(ev)
        -- If overlays are active, show the guard dialog before proceeding.
        if overlay.any_enabled() then
            guard.show_dialog(disp, fu.UIManager, function() refresh_ui(itms) end)
            -- If user chose "Keep Overlay", any_enabled() is still true — bail out.
            if overlay.any_enabled() then return end
        end
        local resolve, res_err = core.get_resolve()
        if not resolve then
            show_error(itms, res_err)
            return
        end
        local ok = resolve:OpenPage("deliver")
        if not ok then
            show_error(itms, "OpenPage('deliver') failed")
        end
    end

    -- §7.17: clear singleton flag on close so the next launch is not blocked.
    -- Stop the guard timer first — every Start() needs a Stop() in the close handler.
    win.On.SafeZoneWin.Close = function(ev)
        guard.stop()
        if fu then fu:SetData(SINGLETON_KEY, nil) end
        disp:ExitLoop()
    end
end

-- Opens the SafeZone GUI window. Blocks until the window is closed.
function M.open()
    if not fu then
        error("[SafeZone] fu (Fusion application) is unavailable — run inside DaVinci Resolve")
    end

    -- Clear any stale singleton flag left by a previous crash, then re-set it.
    -- A second window opening is better than the window never appearing.
    fu:SetData(SINGLETON_KEY, nil)

    local ui   = fu.UIManager
    local disp = bmd.UIDispatcher(ui)

    if not ui or not disp then
        error("[SafeZone] UIManager or UIDispatcher is unavailable")
    end

    -- Mark as open before building (crash leaves flag set — acceptable one-time annoyance)
    fu:SetData(SINGLETON_KEY, true)

    local win  = build_window(ui, disp)
    local itms = win:GetItems()

    wire_events(win, itms, disp)

    -- Start the pre-render guard. The callback refreshes labels after the user disables overlays.
    guard.start(disp, function() refresh_ui(itms) end)

    -- Initial UI state
    refresh_ui(itms)

    win:Show()
    disp:RunLoop()
    win:Hide()
end

return M
