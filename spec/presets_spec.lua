-- Unit tests for lib/presets.lua
-- Run with: busted spec/
-- These tests have zero Resolve dependency — pure Lua logic only.

package.path = package.path .. ";./SafeZone/lib/?.lua"

local presets = require("presets")

describe("presets.lookup", function()
    it("finds a platform preset by key", function()
        local p = presets.lookup("tiktok_9x16")
        assert.is_not_nil(p)
        assert.equals("TikTok", p.label)
        assert.equals("9x16", p.ratio)
        assert.equals("platform", p.category)
    end)

    it("finds a ratio preset by key", function()
        local p = presets.lookup("ratio_9x16")
        assert.is_not_nil(p)
        assert.equals("9:16", p.label)
        assert.equals("ratio", p.category)
    end)

    it("returns nil for an unknown key", function()
        assert.is_nil(presets.lookup("nonexistent"))
    end)

    it("returns nil for an empty string", function()
        assert.is_nil(presets.lookup(""))
    end)

    it("returns nil for nil input", function()
        assert.is_nil(presets.lookup(nil))
    end)

    it("each preset has all required fields", function()
        for _, p in ipairs(presets.all()) do
            assert.is_string(p.key)
            assert.is_string(p.label)
            assert.is_string(p.ratio)
            assert.is_string(p.category)
            assert.is_string(p.asset)
            assert.is_string(p.clip_name_prefix)
            -- clip_name_prefix must start with __SZ_ (state model invariant)
            assert.equals("__SZ_", p.clip_name_prefix:sub(1, 5))
        end
    end)
end)

describe("presets.by_ratio", function()
    it("returns all presets matching 9x16", function()
        local results = presets.by_ratio("9x16")
        -- Should include: TikTok, IG Reels, YT Shorts (platform) + ratio_9x16
        assert.is_true(#results >= 3)
        for _, p in ipairs(results) do
            assert.equals("9x16", p.ratio)
        end
    end)

    it("returns all presets matching 16x9", function()
        local results = presets.by_ratio("16x9")
        -- Should include: YT 16x9, X/Twitter (platform) + ratio_16x9
        assert.is_true(#results >= 2)
    end)

    it("returns an empty table for an unknown ratio", function()
        local results = presets.by_ratio("3x2")
        assert.equals(0, #results)
    end)

    it("returns an empty table for nil", function()
        local results = presets.by_ratio(nil)
        assert.equals(0, #results)
    end)
end)

describe("presets.all", function()
    it("returns all 12 presets", function()
        local all = presets.all()
        assert.equals(12, #all)
    end)

    it("returns a copy — mutations do not affect internal table", function()
        local all = presets.all()
        all[1] = nil
        local all2 = presets.all()
        assert.equals(12, #all2)
    end)

    it("every key is unique", function()
        local seen = {}
        for _, p in ipairs(presets.all()) do
            assert.is_nil(seen[p.key], "Duplicate key: " .. p.key)
            seen[p.key] = true
        end
    end)

    it("every clip_name_prefix is unique", function()
        local seen = {}
        for _, p in ipairs(presets.all()) do
            assert.is_nil(seen[p.clip_name_prefix], "Duplicate prefix: " .. p.clip_name_prefix)
            seen[p.clip_name_prefix] = true
        end
    end)
end)
