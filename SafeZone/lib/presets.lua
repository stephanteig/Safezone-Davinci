local M = {}

-- All SafeZone overlay presets. Single source of truth for what platforms/ratios exist.
-- Pure data module — no Resolve dependency, fully unit-testable.
local PRESETS = {
    -- Platform presets (platform-specific UI safe zone overlays)
    {
        key      = "tiktok_9x16",
        label    = "TikTok",
        ratio    = "9x16",
        category = "platform",
        asset    = "platform/tiktok_9x16.png",
        clip_name_prefix = "__SZ_TikTok",
    },
    {
        key      = "ig_reels_9x16",
        label    = "IG Reels",
        ratio    = "9x16",
        category = "platform",
        asset    = "platform/ig_reels_9x16.png",
        clip_name_prefix = "__SZ_IGReels",
    },
    {
        key      = "yt_shorts_9x16",
        label    = "YT Shorts",
        ratio    = "9x16",
        category = "platform",
        asset    = "platform/yt_shorts_9x16.png",
        clip_name_prefix = "__SZ_YTShorts",
    },
    {
        key      = "ig_feed_4x5",
        label    = "IG Feed (4:5)",
        ratio    = "4x5",
        category = "platform",
        asset    = "platform/ig_feed_4x5.png",
        clip_name_prefix = "__SZ_IGFeed",
    },
    {
        key      = "ig_post_1x1",
        label    = "IG Post (1:1)",
        ratio    = "1x1",
        category = "platform",
        asset    = "platform/ig_post_1x1.png",
        clip_name_prefix = "__SZ_IGPost",
    },
    {
        key      = "yt_16x9",
        label    = "YT (16:9)",
        ratio    = "16x9",
        category = "platform",
        asset    = "platform/yt_16x9.png",
        clip_name_prefix = "__SZ_YT",
    },
    {
        key      = "x_twitter_16x9",
        label    = "X / Twitter",
        ratio    = "16x9",
        category = "platform",
        asset    = "platform/x_twitter_16x9.png",
        clip_name_prefix = "__SZ_XTwitter",
    },

    -- Ratio-only presets (pure crop frame, no platform UI)
    {
        key      = "ratio_9x16",
        label    = "9:16",
        ratio    = "9x16",
        category = "ratio",
        asset    = "ratio/frame_9x16.png",
        clip_name_prefix = "__SZ_R9x16",
    },
    {
        key      = "ratio_4x5",
        label    = "4:5",
        ratio    = "4x5",
        category = "ratio",
        asset    = "ratio/frame_4x5.png",
        clip_name_prefix = "__SZ_R4x5",
    },
    {
        key      = "ratio_1x1",
        label    = "1:1",
        ratio    = "1x1",
        category = "ratio",
        asset    = "ratio/frame_1x1.png",
        clip_name_prefix = "__SZ_R1x1",
    },
    {
        key      = "ratio_4x3",
        label    = "4:3",
        ratio    = "4x3",
        category = "ratio",
        asset    = "ratio/frame_4x3.png",
        clip_name_prefix = "__SZ_R4x3",
    },
    {
        key      = "ratio_16x9",
        label    = "16:9",
        ratio    = "16x9",
        category = "ratio",
        asset    = "ratio/frame_16x9.png",
        clip_name_prefix = "__SZ_R16x9",
    },
}

-- Build a key-indexed lookup table at load time for O(1) access.
local _by_key = {}
for _, p in ipairs(PRESETS) do
    _by_key[p.key] = p
end

-- Returns the preset table for a given key, or nil if not found.
function M.lookup(key)
    return _by_key[key]
end

-- Returns all presets whose ratio field matches the given ratio string (e.g. "9x16").
-- Returns an empty table if none match.
function M.by_ratio(ratio)
    local result = {}
    for _, p in ipairs(PRESETS) do
        if p.ratio == ratio then
            result[#result + 1] = p
        end
    end
    return result
end

-- Returns all presets as a sequential table (copy, not reference).
function M.all()
    local result = {}
    for i, p in ipairs(PRESETS) do
        result[i] = p
    end
    return result
end

return M
