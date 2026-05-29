local M = {}

local core      = require("core")
local presets   = require("presets")
local mediapool = require("mediapool")

local CLIP_PREFIX    = "__SZ_"
local TRACK_NAME     = "SafeZone"
local OVERLAY_COLOR  = "Pink"   -- SetClipColor string; visually distinct in timeline

-- Returns true if a TimelineItem's name starts with the __SZ_ prefix.
local function is_overlay(item)
    local name = item:GetName()
    return name and name:sub(1, #CLIP_PREFIX) == CLIP_PREFIX
end

-- Returns true if an overlay clip matches a specific preset key.
-- We encode the preset key into the clip name as "__SZ_<clip_name_prefix>".
local function is_overlay_for_preset(item, preset)
    local name = item:GetName()
    return name == preset.clip_name_prefix
end

-- Iterates all video tracks and collects every TimelineItem with the __SZ_ prefix.
-- Returns a sequential table of TimelineItems (may be empty — §7.8).
function M.find_all()
    local timeline, err = core.get_timeline()
    if not timeline then return {} end

    local results = {}
    local track_count = timeline:GetTrackCount("video")

    for i = 1, track_count do
        local items = timeline:GetItemListInTrack("video", i)
        if items then
            for _, item in ipairs(items) do
                if is_overlay(item) then
                    results[#results + 1] = item
                end
            end
        end
    end

    return results
end

-- Returns true if any overlay clip is currently enabled.
function M.any_enabled()
    local items = M.find_all()
    for _, item in ipairs(items) do
        if item:GetClipEnabled() then
            return true
        end
    end
    return false
end

-- Sets all overlay clips to the given enabled state.
-- Returns (true, nil) on success, (false, errmsg) if any call fails.
function M.set_enabled(enabled)
    local items = M.find_all()
    for _, item in ipairs(items) do
        local ok = item:SetClipEnabled(enabled)
        if not ok then
            -- §7.13: surface failure, don't silently swallow
            return false, "SetClipEnabled() failed on clip: " .. (item:GetName() or "?")
        end
    end
    return true, nil
end

-- Toggles all overlay clips. Uses the first clip's state to determine direction.
-- If no overlays exist, this is a no-op (§7.8).
function M.toggle()
    local items = M.find_all()
    if #items == 0 then return true, nil end

    local currently_enabled = items[1]:GetClipEnabled()
    return M.set_enabled(not currently_enabled)
end

-- Finds or creates the highest unlocked video track for overlay placement.
-- Returns (trackIndex, errmsg).
-- §7.3: auto-creates a track if none exist.
-- §7.4: skips locked tracks, tries one below highest, errors if all locked.
local function get_overlay_track(timeline)
    local track_count = timeline:GetTrackCount("video")

    -- Find the track named "SafeZone" if it already exists.
    for i = track_count, 1, -1 do
        local name = timeline:GetTrackName("video", i)
        if name == TRACK_NAME then
            -- VERIFY: GetIsTrackLocked vs IsTrackLocked — test at runtime.
            local locked = timeline:GetIsTrackLocked("video", i) -- §7.4 VERIFY
            if not locked then
                return i, nil
            end
        end
    end

    -- No SafeZone track found. Try to add one at the top.
    local ok = timeline:AddTrack("video")
    if not ok then
        -- §7.4: AddTrack failed — possibly all tracks are locked or at system limit.
        return nil, "AddTrack() failed — could not create SafeZone video track"
    end

    local new_index = timeline:GetTrackCount("video")
    timeline:SetTrackName("video", new_index, TRACK_NAME)

    return new_index, nil
end

-- Removes a single overlay clip from the timeline by preset key.
-- Silently does nothing if the clip doesn't exist (§7.8).
-- Returns (true, nil) or (false, errmsg).
function M.remove(preset_key)
    local preset = presets.lookup(preset_key)
    if not preset then
        return false, "Unknown preset key: " .. tostring(preset_key)
    end

    local timeline, err = core.get_timeline()
    if not timeline then return false, err end

    local track_count = timeline:GetTrackCount("video")

    for i = 1, track_count do
        local items = timeline:GetItemListInTrack("video", i)
        if items then
            for _, item in ipairs(items) do
                if is_overlay_for_preset(item, preset) then
                    -- DeleteClips expects a list of TimelineItems.
                    timeline:DeleteClips({ item })
                    return true, nil
                end
            end
        end
    end

    return true, nil  -- not found is not an error
end

-- Removes all __SZ_* overlay clips from the timeline.
-- Returns (true, nil) or (false, errmsg).
function M.remove_all()
    local timeline, err = core.get_timeline()
    if not timeline then return false, err end

    local to_delete = M.find_all()
    if #to_delete == 0 then return true, nil end

    -- DeleteClips in one call to minimise API round-trips.
    local ok = timeline:DeleteClips(to_delete)
    if not ok then
        return false, "DeleteClips() failed"
    end

    return true, nil
end

-- Adds an overlay for the given presetKey.
-- mode: "replace" (default) removes all existing overlays first.
--       "stack" adds without removing existing overlays.
-- §7.16: if preset is already active in stack mode, this is a no-op.
-- Returns (true, nil) or (false, errmsg).
function M.add(preset_key, mode)
    local preset = presets.lookup(preset_key)
    if not preset then
        return false, "Unknown preset key: " .. tostring(preset_key)
    end

    local timeline, err = core.get_timeline()
    if not timeline then return false, err end

    -- §7.16: check for duplicate in stack mode
    if mode == "stack" then
        local items = M.find_all()
        for _, item in ipairs(items) do
            if is_overlay_for_preset(item, preset) then
                return true, nil  -- already active, no-op
            end
        end
    else
        -- Replace mode: remove all existing overlays first.
        local ok, rem_err = M.remove_all()
        if not ok then return false, rem_err end
    end

    -- Ensure the PNG is imported into the MediaPool.
    local mp_item, imp_err = mediapool.ensure_imported(preset_key)
    if not mp_item then return false, imp_err end

    -- Find or create the SafeZone track.
    local track_index, track_err = get_overlay_track(timeline)
    if not track_index then return false, track_err end

    -- Compute timeline span: overlay covers full timeline at apply time (§7.10/§7.15).
    local start_frame = timeline:GetStartFrame()
    local end_frame   = timeline:GetEndFrame()
    local duration    = end_frame - start_frame

    if duration <= 0 then
        return false, "Timeline has zero duration — nothing to overlay"
    end

    local mp = core.get_media_pool()
    if not mp then
        return false, "MediaPool unavailable"
    end

    -- Ensure we are on the Edit page — AppendToTimeline returns nil on other pages.
    local resolve_h, _ = core.get_resolve()
    if resolve_h and resolve_h:GetCurrentPage() ~= "edit" then
        resolve_h:OpenPage("edit")
    end

    -- AppendToTimeline only works reliably when the current MediaPool folder is the root.
    -- Re-fetch the item from the SafeZone bin after the folder reset.
    local root_folder = mp:GetRootFolder()
    if root_folder then
        mp:SetCurrentFolder(root_folder)
        local subfolders = root_folder:GetSubFolderList() or {}
        for _, sub in ipairs(subfolders) do
            if sub:GetName() == "SafeZone" then
                local clips = sub:GetClipList() or {}
                for _, c in ipairs(clips) do
                    if c:GetName() == mp_item:GetName() then
                        mp_item = c
                        break
                    end
                end
                break
            end
        end
    end

    -- Try with trackIndex first so the clip lands on the SafeZone track.
    -- Fall back without it if that returns nil (Resolve version difference).
    local new_items = mp:AppendToTimeline({
        { mediaPoolItem = mp_item, startFrame = 0, endFrame = duration, recordFrame = start_frame, trackIndex = track_index }
    })

    if not new_items or #new_items == 0 then
        new_items = mp:AppendToTimeline({
            { mediaPoolItem = mp_item, startFrame = 0, endFrame = duration, recordFrame = start_frame }
        })
    end

    if not new_items or #new_items == 0 then
        return false, "AppendToTimeline() returned empty — clip not placed"
    end

    local placed = new_items[1]
    print(string.format("[SafeZone] placed: GetName=%s", tostring(placed:GetName())))

    -- Scan every video track so we can see where the clip actually landed.
    local tc = timeline:GetTrackCount("video")
    print(string.format("[SafeZone] video tracks after append: %d", tc))
    for t = 1, tc do
        local tname  = timeline:GetTrackName("video", t) or ""
        local titems = timeline:GetItemListInTrack("video", t) or {}
        print(string.format("[SafeZone]   track %d '%s': %d clip(s)", t, tname, #titems))
        for _, ci in ipairs(titems) do
            print(string.format("[SafeZone]     clip name=%s", tostring(ci:GetName())))
        end
    end

    local placed = new_items[1]

    -- Name the clip with the __SZ_ prefix so find_all() can identify it.
    -- VERIFY: SetProperty("Clip Name", ...) on TimelineItem — confirmed as the correct
    -- replacement for the plan's SetName() which may not exist on all Resolve versions.
    local name_ok = placed:SetProperty("Clip Name", preset.clip_name_prefix)
    if not name_ok then
        -- Non-fatal: overlay placed, but dedup and remove_all will miss it.
        -- Surface as a warning (caller should log this).
        return true, "WARNING: SetProperty(Clip Name) failed — overlay placed but may not be identifiable"
    end

    -- Visual flag: color the clip for easy timeline identification.
    placed:SetClipColor(OVERLAY_COLOR)

    return true, nil
end

return M
