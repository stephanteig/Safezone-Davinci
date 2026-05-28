local M = {}

-- Resolve handle getters. All lazy-init — never call Resolve() at module load time
-- because the global may not be injected until the script is actually running inside Resolve.
--
-- Each function returns (value, errmsg). On failure: (nil, string).
-- Callers must check for nil before using the returned handle.

function M.get_resolve()
    local ok, res = pcall(Resolve)
    if not ok or not res then
        return nil, "Resolve() is unavailable — run this script from inside DaVinci Resolve"
    end
    return res, nil
end

function M.get_project()
    local resolve, err = M.get_resolve()
    if not resolve then return nil, err end

    local pm = resolve:GetProjectManager()
    if not pm then
        return nil, "GetProjectManager() returned nil"
    end

    local project = pm:GetCurrentProject()
    if not project then
        return nil, "No project is currently open"
    end

    -- §7.1: GetCurrentProject() returns a default "Untitled" object even with no project.
    -- A nil name would be a strong signal of no real project, but in practice
    -- GetCurrentProject() on Resolve 18+ returns a valid object whenever a project is loaded.
    return project, nil
end

function M.get_timeline()
    local project, err = M.get_project()
    if not project then return nil, err end

    local timeline = project:GetCurrentTimeline()
    if not timeline then
        -- §7.2: no timeline in project
        return nil, "No timeline is currently open"
    end

    return timeline, nil
end

function M.get_media_pool()
    local project, err = M.get_project()
    if not project then return nil, err end

    local mp = project:GetMediaPool()
    if not mp then
        return nil, "GetMediaPool() returned nil"
    end

    return mp, nil
end

-- Returns the absolute path to the SafeZone plugin root directory.
-- Derives it from this file's path using debug.getinfo (Lua 5.1 compatible).
function M.plugin_root()
    local info = debug.getinfo(1, "S")
    local src = info.source
    -- src is "@/path/to/SafeZone/lib/core.lua"; strip the "@" and go up two levels.
    if src:sub(1, 1) == "@" then
        src = src:sub(2)
    end
    -- Strip /lib/core.lua from the end
    return src:match("^(.+)/lib/core%.lua$")
end

return M
