local M = {}

local core    = require("core")
local presets = require("presets")

local BIN_NAME = "SafeZone"

-- Returns the SafeZone MediaPool bin, creating it if it doesn't exist.
-- Returns (folder, errmsg).
local function find_or_create_bin(mp)
    local root = mp:GetRootFolder()
    if not root then
        return nil, "GetRootFolder() returned nil"
    end

    local subfolders = root:GetSubFolderList()
    if subfolders then
        for _, sub in ipairs(subfolders) do
            if sub:GetName() == BIN_NAME then
                return sub, nil
            end
        end
    end

    local bin = mp:AddSubFolder(root, BIN_NAME)
    if not bin then
        return nil, "AddSubFolder() failed — could not create SafeZone bin"
    end

    return bin, nil
end

-- Checks whether a clip with the given name already exists in the folder.
-- Returns the MediaPoolItem if found, nil otherwise.
local function find_clip_in_folder(folder, clip_name)
    local clips = folder:GetClipList()
    if not clips then return nil end

    for _, item in ipairs(clips) do
        if item:GetName() == clip_name then
            return item
        end
    end

    return nil
end

-- Ensures the PNG for the given presetKey is imported into the SafeZone MediaPool bin.
-- Reuses an existing import if a clip with the same name is already in the bin (§7.7).
-- Returns (MediaPoolItem, errmsg).
function M.ensure_imported(preset_key)
    local preset = presets.lookup(preset_key)
    if not preset then
        return nil, "Unknown preset key: " .. tostring(preset_key)
    end

    local mp, err = core.get_media_pool()
    if not mp then return nil, err end

    local bin, bin_err = find_or_create_bin(mp)
    if not bin then return nil, bin_err end

    -- The clip name used for dedup is the asset filename without extension.
    local clip_name = preset.clip_name_prefix

    -- §7.7: check for existing import before reimporting
    local existing = find_clip_in_folder(bin, clip_name)
    if existing then
        return existing, nil
    end

    -- Resolve the absolute path to the asset PNG.
    local plugin_root = core.plugin_root()
    if not plugin_root then
        return nil, "Could not determine plugin root path"
    end

    local asset_path = plugin_root .. "/assets/" .. preset.asset
    -- §7.6: verify file exists before attempting import (os.rename is a readable Lua 5.1 existence check)
    local fh = io.open(asset_path, "rb")
    if not fh then
        return nil, "Asset file not found: " .. asset_path
    end
    fh:close()

    -- Import into the SafeZone bin. SetCurrentFolder first so ImportMedia lands there.
    mp:SetCurrentFolder(bin)
    local imported = mp:ImportMedia({ asset_path })

    if not imported or #imported == 0 then
        return nil, "ImportMedia() returned empty list for: " .. asset_path
    end

    local item = imported[1]

    -- Rename the clip so dedup finds it by the canonical prefix name on future calls.
    -- VERIFY: SetProperty("Clip Name", ...) confirmed as the correct method on MediaPoolItem;
    -- some versions may require a different approach.
    local ok = item:SetClipProperty("Clip Name", clip_name)
    if not ok then
        -- Non-fatal: import succeeded, dedup will re-import next time but that's acceptable.
    end

    return item, nil
end

return M
