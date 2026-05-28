local M = {}

-- Tolerance in pixels for ratio classification. Handles odd-dimension timelines (e.g. 1079x1920).
local TOLERANCE = 2

-- Canonical ratios as {width_parts, height_parts, key} in priority order.
-- Order matters when a resolution could match multiple ratios (it shouldn't, but be explicit).
local RATIO_TABLE = {
    { w = 9,  h = 16, key = "9x16"  },
    { w = 4,  h = 5,  key = "4x5"   },
    { w = 1,  h = 1,  key = "1x1"   },
    { w = 4,  h = 3,  key = "4x3"   },
    { w = 16, h = 9,  key = "16x9"  },
}

-- Pure function. Takes timeline width and height in pixels, returns a ratio key string
-- ("9x16", "4x5", "1x1", "4x3", "16x9") or "unknown".
-- Applies ±TOLERANCE px tolerance to handle slightly off-spec resolutions.
function M.classify_ratio(w, h)
    if not w or not h or w <= 0 or h <= 0 then
        return "unknown"
    end

    for _, r in ipairs(RATIO_TABLE) do
        -- Scale canonical ratio to match the longer dimension, then compare shorter.
        local scaled_short
        if r.w <= r.h then
            -- Portrait or square: h is the longer side
            scaled_short = math.floor(h * r.w / r.h + 0.5)
            if math.abs(w - scaled_short) <= TOLERANCE then
                return r.key
            end
        else
            -- Landscape: w is the longer side
            scaled_short = math.floor(w * r.h / r.w + 0.5)
            if math.abs(h - scaled_short) <= TOLERANCE then
                return r.key
            end
        end
    end

    return "unknown"
end

-- Reads the current timeline's resolution via the Resolve API and classifies it.
-- Returns (ratioKey, width, height) on success, or ("unknown", nil, nil) on failure.
-- Depends on core module — loaded lazily to avoid circular dep at module load time.
function M.detect_ratio()
    local core = require("core")

    local timeline, err = core.get_timeline()
    if not timeline then
        return "unknown", nil, nil
    end

    local w = tonumber(timeline:GetSetting("timelineResolutionWidth"))
    local h = tonumber(timeline:GetSetting("timelineResolutionHeight"))

    if not w or not h then
        return "unknown", nil, nil
    end

    return M.classify_ratio(w, h), w, h
end

return M
