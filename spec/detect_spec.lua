-- Unit tests for lib/detect.lua — classify_ratio() only.
-- detect_ratio() is NOT tested here because it calls core.get_timeline() (Resolve API).
-- Run with: busted spec/

package.path = package.path .. ";./SafeZone/lib/?.lua"

local detect = require("detect")

describe("detect.classify_ratio", function()
    -- Canonical portrait resolutions
    it("classifies 1080x1920 as 9x16", function()
        assert.equals("9x16", detect.classify_ratio(1080, 1920))
    end)

    it("classifies 1080x1350 as 4x5", function()
        assert.equals("4x5", detect.classify_ratio(1080, 1350))
    end)

    it("classifies 1080x1080 as 1x1", function()
        assert.equals("1x1", detect.classify_ratio(1080, 1080))
    end)

    -- Canonical landscape resolutions
    it("classifies 1440x1080 as 4x3", function()
        assert.equals("4x3", detect.classify_ratio(1440, 1080))
    end)

    it("classifies 1920x1080 as 16x9", function()
        assert.equals("16x9", detect.classify_ratio(1920, 1080))
    end)

    it("classifies 3840x2160 (4K) as 16x9", function()
        assert.equals("16x9", detect.classify_ratio(3840, 2160))
    end)

    it("classifies 2160x3840 (4K portrait) as 9x16", function()
        assert.equals("9x16", detect.classify_ratio(2160, 3840))
    end)

    -- Tolerance: ±2px on the shorter dimension
    it("tolerates 1079x1920 (1px short) as 9x16", function()
        assert.equals("9x16", detect.classify_ratio(1079, 1920))
    end)

    it("tolerates 1081x1920 (1px over) as 9x16", function()
        assert.equals("9x16", detect.classify_ratio(1081, 1920))
    end)

    it("tolerates 1082x1920 (2px over, at limit) as 9x16", function()
        assert.equals("9x16", detect.classify_ratio(1082, 1920))
    end)

    it("does not tolerate 1083x1920 (3px over, past limit)", function()
        assert.not_equals("9x16", detect.classify_ratio(1083, 1920))
    end)

    -- Unknown/custom ratios
    it("returns 'unknown' for 1920x800 (non-preset ratio)", function()
        assert.equals("unknown", detect.classify_ratio(1920, 800))
    end)

    it("returns 'unknown' for 4096x2160 (DCI 17:9)", function()
        assert.equals("unknown", detect.classify_ratio(4096, 2160))
    end)

    -- Guard against bad inputs
    it("returns 'unknown' for zero width", function()
        assert.equals("unknown", detect.classify_ratio(0, 1080))
    end)

    it("returns 'unknown' for zero height", function()
        assert.equals("unknown", detect.classify_ratio(1920, 0))
    end)

    it("returns 'unknown' for nil inputs", function()
        assert.equals("unknown", detect.classify_ratio(nil, nil))
    end)

    it("returns 'unknown' for negative values", function()
        assert.equals("unknown", detect.classify_ratio(-1920, -1080))
    end)
end)
