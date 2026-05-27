# SafeZone — DaVinci Resolve Plugin Plan

> Working name: **SafeZone** (rename before public release — suggestions: `Beacon`, `Bracket`, `Edges`, `Aperture`, `Marker` — see Open Questions).

A Lua-based DaVinci Resolve plugin that adds toggle-able social media safe zone and aspect ratio overlays to the viewer via PNG clips on the timeline. Built because DaVinci's native viewer-overlay system (View > Social Media Guides) is not exposed in the scripting API.

---

## 1. Goal

Give editors a one-click way to see platform-specific safe zones (TikTok UI, IG Reels UI, etc.) and pure aspect ratio crop frames in the DaVinci viewer, with hotkey toggles and protection against accidentally rendering the overlay into a deliverable.

### Success criteria

- Open GUI via user-mapped keyboard shortcut → < 200 ms
- Apply overlay → < 500 ms (including first-time PNG import to MediaPool)
- Toggle overlay on/off via user-mapped keyboard shortcut → < 100 ms
- Auto-detects current timeline aspect ratio and highlights relevant platform buttons
- Cannot accidentally render overlay into client deliverable (with explicit bypass available)
- Zero dependency on Fusion compositions

### Non-goals (v1)

- Native viewer overlays (impossible via API)
- Custom user-uploaded PNGs (later version)
- Aspect ratio markers for cinematic ratios beyond what's bundled
- Cross-platform (this is macOS-first, paths assume macOS layout — Windows/Linux paths documented but not tested)

---

## 2. Locked design decisions

From the design Q&A:

| Decision | Choice |
|---|---|
| Safe zone style | **Both** — platform-specific (TikTok ≠ IG Reels) as default, ratio-only frames as fallback |
| Pre-render guard | **Maximum paranoid + bypass** — Render button in GUI, passive warning if Deliver opened with overlay enabled, auto-disable on Deliver navigation with `[Disable & Continue]` / `[Keep Overlay (will render)]` dialog |
| Multiple overlays | **Replace by default, Shift+click to stack** — picking a new overlay replaces current; Shift+click adds to stack for cross-posting validation |

---

## 3. Architecture

### File structure

```
SafeZone/
├── SafeZone.lua                    # Entry: opens GUI (map "SafeZone" shortcut here)
├── SafeZone_Toggle.lua             # Entry: toggles enabled state on all overlays
├── SafeZone_Render.lua             # Entry: disable overlays + open Deliver (optional shortcut)
├── lib/
│   ├── core.lua                    # Shared logic, Resolve handle helpers
│   ├── detect.lua                  # Timeline aspect ratio detection
│   ├── overlay.lua                 # Add/remove/toggle/find overlay clips
│   ├── mediapool.lua               # PNG import with dedup
│   ├── presets.lua                 # Platform + ratio preset definitions
│   ├── guard.lua                   # Pre-render watcher (page polling)
│   └── ui.lua                      # UI Manager window builder
├── assets/
│   ├── platform/
│   │   ├── tiktok_9x16.png
│   │   ├── ig_reels_9x16.png
│   │   ├── yt_shorts_9x16.png
│   │   ├── ig_feed_4x5.png
│   │   ├── ig_post_1x1.png
│   │   ├── yt_16x9.png
│   │   └── x_twitter_16x9.png
│   └── ratio/
│       ├── frame_9x16.png
│       ├── frame_4x5.png
│       ├── frame_4x3.png
│       ├── frame_1x1.png
│       └── frame_16x9.png
└── README.md
```

### Components

1. **Entry scripts** — three thin Lua files that Resolve picks up automatically and exposes as keyboard-mappable actions. They each load `lib/core.lua` and call into the appropriate function.

2. **Core module** — owns the Resolve handle (`Resolve()`, project, timeline, mediaPool). Provides safe getters with nil checks. All other modules go through core for Resolve API access.

3. **Detect module** — reads `Timeline:GetSetting("timelineResolutionWidth")` and `"timelineResolutionHeight"`, calculates ratio, returns the matching preset key (`"9x16"`, `"1x1"`, etc.) or `"unknown"`.

4. **Overlay module** — the heart of the plugin. Manages the lifecycle of overlay clips:
   - `add(presetKey, mode)` — mode is `"replace"` or `"stack"`
   - `remove(presetKey)` — single
   - `remove_all()` — nuke all `__SZ_*` clips
   - `find_all()` — returns list of overlay TimelineItems
   - `toggle()` — flip `SetClipEnabled` on all overlay clips
   - `set_enabled(bool)` — set all overlays to specific state

5. **MediaPool module** — handles PNG import. Maintains a SafeZone bin in the MediaPool. Before importing, checks if a clip with matching name already exists — if so, reuses it. Idempotent.

6. **Presets module** — single source of truth for what platforms/ratios exist. Each preset has:
   ```lua
   {
       key = "tiktok_9x16",
       label = "TikTok",
       ratio = "9x16",
       category = "platform",  -- or "ratio"
       asset = "platform/tiktok_9x16.png",
       clip_name_prefix = "__SZ_TikTok"
   }
   ```

7. **Guard module** — the pre-render protector. When GUI is open, polls `resolve:GetCurrentPage()` every ~500ms via a UI Manager timer. If page changes to `"deliver"` and any overlay is enabled, fires the bypass dialog.

8. **UI module** — builds and shows the floating GUI using `fu.UIManager` and `bmd.UIDispatcher`.

### State management

All state lives on the timeline. Overlay clips are identified by a `__SZ_` prefix in their name (e.g. `__SZ_TikTok_9x16`). The plugin never writes config files, project metadata, or hidden state. This means:
- ✅ Survives plugin reinstall
- ✅ Survives Resolve restart
- ✅ Travels with the project file
- ⚠️ User can delete clips manually and plugin handles gracefully

---

## 4. DaVinci Resolve Scripting API reference

All API calls used by this plugin. Verify against the official docs at:
`~/Library/Application Support/Blackmagic Design/DaVinci Resolve/Developer/Scripting/README.txt`

### Getting handles

```lua
-- From a Resolve script (auto-injected globals)
local resolve = Resolve()                       -- top-level
local pm = resolve:GetProjectManager()
local project = pm:GetCurrentProject()          -- nil if no project
local mediaPool = project:GetMediaPool()
local timeline = project:GetCurrentTimeline()   -- nil if no timeline
```

### Page navigation

```lua
resolve:GetCurrentPage()  -- returns "media" | "cut" | "edit" | "fusion" | "color" | "fairlight" | "deliver" | nil
resolve:OpenPage("deliver")  -- returns bool
```

### Timeline introspection

```lua
local w = tonumber(timeline:GetSetting("timelineResolutionWidth"))
local h = tonumber(timeline:GetSetting("timelineResolutionHeight"))
local fps = tonumber(timeline:GetSetting("timelineFrameRate"))

local trackCount = timeline:GetTrackCount("video")  -- "video", "audio", or "subtitle"
local items = timeline:GetItemListInTrack("video", trackIndex)  -- 1-indexed

local startFrame = timeline:GetStartFrame()
local endFrame = timeline:GetEndFrame()
local duration = endFrame - startFrame

local trackName = timeline:GetTrackName("video", trackIndex)
local locked = timeline:GetIsTrackLocked("video", trackIndex)
```

### Adding tracks

```lua
-- Add a new video track at the top
timeline:AddTrack("video")  -- returns bool

-- Set track name for clarity
timeline:SetTrackName("video", newTrackIndex, "SafeZone")
```

### Adding clips to timeline

The `AppendToTimeline` method accepts a list of clipInfo tables:

```lua
local clipInfo = {
    mediaPoolItem = mpItem,
    startFrame = 0,                          -- in-point in source
    endFrame = sourceDurationInFrames,       -- out-point in source
    recordFrame = timelineStartFrame,        -- where on timeline
    trackIndex = targetTrackIndex,           -- 1-indexed
    mediaType = 1                            -- 1 = video, 2 = audio
}
local items = mediaPool:AppendToTimeline({clipInfo})  -- returns list of new TimelineItems
```

⚠️ **Verify in build:** The exact field names for `clipInfo` have changed across Resolve versions. Confirm against installed Resolve's `README.txt`. For stills (PNGs), `startFrame` and `endFrame` define the duration on timeline.

### TimelineItem control

```lua
item:GetName()                          -- string
item:SetName(name)                      -- bool
item:GetClipEnabled()                   -- bool
item:SetClipEnabled(bool)               -- bool — THIS is the toggle workhorse
item:GetStart()                         -- timeline frame
item:GetEnd()                           -- timeline frame
item:GetDuration()                      -- frames
item:GetMediaPoolItem()                 -- back-reference
item:SetClipColor("Orange")             -- visual flag, supports: Orange, Apricot, Yellow, Lime, Olive, Green, Teal, Navy, Blue, Purple, Violet, Pink, Tan, Beige, Brown, Chocolate
```

### MediaPool

```lua
local rootFolder = mediaPool:GetRootFolder()
local currentFolder = mediaPool:GetCurrentFolder()

-- Create or find a SafeZone bin
local function findOrCreateBin(name)
    for _, sub in ipairs(rootFolder:GetSubFolderList()) do
        if sub:GetName() == name then return sub end
    end
    return mediaPool:AddSubFolder(rootFolder, name)
end

mediaPool:SetCurrentFolder(safezoneBin)
local items = mediaPool:ImportMedia({"/abs/path/to/file.png"})  -- returns list of MediaPoolItems
```

### MediaPoolItem

```lua
mpItem:GetName()
mpItem:GetClipProperty("File Path")
mpItem:GetClipProperty()  -- returns dict of all properties
mpItem:GetClipProperty("Frames")  -- duration in frames (for stills, usually 1, but timeline duration when placed is controlled by clipInfo)
```

### Caveats and known issues

- **`Resolve()` global is only available inside scripts run from Resolve's Scripts menu.** When testing externally, use `DaVinciResolveScript.scriptapp("Resolve")` after setting environment variables. The plugin only needs to work from inside Resolve.
- **`GetCurrentProject()` returns a project object even before the user has a project open** — gives a default "Untitled" project. Check `project:GetName()` against expected state if needed.
- **Modifications to a locked track silently fail.** Always check return values.
- **`SetClipEnabled` returns `true` on success.** Check it.
- **No render-hook API exists.** This is why the pre-render guard relies on polling the current page, not on intercepting render.
- **`GetCurrentPage()` can return `nil`** if Resolve is in an unusual state.

---

## 5. UI Manager reference

UI Manager is Fusion's GUI framework, accessible from Resolve scripts. Build pattern:

```lua
local ui = fu.UIManager
local disp = bmd.UIDispatcher(ui)

local win = disp:AddWindow({
    ID = "SafeZoneWin",
    WindowTitle = "SafeZone",
    Geometry = { 100, 100, 360, 520 },
    Spacing = 8,
    Margin = 12,

    ui:VGroup{
        ID = "root",

        ui:Label{
            ID = "status",
            Text = "Detected: 9:16",
            Alignment = { AlignHCenter = true },
            Font = ui:Font{ PixelSize = 14, Bold = true },
        },

        ui:HGap(0, 4),

        ui:Label{ Text = "Platform" },
        ui:HGroup{
            ui:Button{ ID = "btn_tiktok",    Text = "TikTok" },
            ui:Button{ ID = "btn_ig_reels",  Text = "IG Reels" },
            ui:Button{ ID = "btn_yt_shorts", Text = "YT Shorts" },
        },
        ui:HGroup{
            ui:Button{ ID = "btn_ig_feed",   Text = "IG Feed (4:5)" },
            ui:Button{ ID = "btn_ig_post",   Text = "IG Post (1:1)" },
            ui:Button{ ID = "btn_yt_16x9",   Text = "YT (16:9)" },
        },

        ui:Label{ Text = "Aspect ratio only" },
        ui:HGroup{
            ui:Button{ ID = "btn_r_9x16", Text = "9:16" },
            ui:Button{ ID = "btn_r_4x5",  Text = "4:5" },
            ui:Button{ ID = "btn_r_1x1",  Text = "1:1" },
            ui:Button{ ID = "btn_r_4x3",  Text = "4:3" },
            ui:Button{ ID = "btn_r_16x9", Text = "16:9" },
        },

        ui:HGap(0, 8),

        ui:HGroup{
            ui:CheckBox{ ID = "stack_mode", Text = "Stack mode (or hold Shift on click)" },
        },

        ui:HGap(0, 8),

        ui:HGroup{
            ui:Button{ ID = "btn_toggle",     Text = "Toggle overlay" },
            ui:Button{ ID = "btn_remove_all", Text = "Remove all" },
        },

        ui:HGroup{
            ui:Button{
                ID = "btn_render",
                Text = "🛡  Safe Render",
                Font = ui:Font{ Bold = true },
            },
        },

        ui:Label{
            ID = "footer",
            Text = "No overlays active",
            Alignment = { AlignHCenter = true },
        },
    },
})
```

### Event binding

```lua
win.On.SafeZoneWin.Close = function(ev)
    disp:ExitLoop()
end

win.On.btn_tiktok.Clicked = function(ev)
    local stack = win:GetItems().stack_mode.Checked
    -- ev.modifiers may contain shift state — VERIFY IN BUILD
    overlay.add("tiktok_9x16", stack and "stack" or "replace")
    refresh_footer()
end

win.On.btn_toggle.Clicked = function(ev)
    overlay.toggle()
end

win.On.btn_render.Clicked = function(ev)
    overlay.set_enabled(false)
    resolve:OpenPage("deliver")
end
```

### Pre-render guard timer

```lua
-- Poll current page every 500ms
local last_page = resolve:GetCurrentPage()
local guard_timer = ui:Timer{ Interval = 500 }
guard_timer.On.Timeout = function()
    local page = resolve:GetCurrentPage()
    if page == "deliver" and last_page ~= "deliver" then
        if overlay.any_enabled() then
            show_render_guard_dialog()  -- auto-disable + bypass option
        end
    end
    last_page = page
end
guard_timer:Start()
```

⚠️ **The timer only runs while GUI window is open.** Document this clearly. If user closes GUI and then navigates to Deliver, there's no protection. The intended workflow is: keep the small GUI window open during the session.

### Modifier key detection

UI Manager button clicks may or may not include modifier state in the event object depending on Resolve version. Two fallbacks:

1. **Preferred:** check `ev.modifiers` or `ev.Modifiers` in the click handler. Search the Fusion UI Manager forum / `fu.UIManager` source if unclear.
2. **Fallback:** the explicit `stack_mode` checkbox in the GUI (always works).

Implement the checkbox as primary; treat Shift-detection as a nice-to-have that doesn't block v1.

### Show & loop

```lua
win:Show()
disp:RunLoop()
win:Hide()
```

---

## 6. Implementation phases

Phased so each is independently testable. Each phase ends with a working state.

### Phase 1 — Foundation (no UI yet)

Goal: All non-GUI infrastructure works from console.

- `lib/core.lua` — Resolve/project/timeline/mediaPool getters with nil checks
- `lib/presets.lua` — preset table, lookup functions
- `lib/detect.lua` — `detect_ratio()` returns preset key
- `lib/mediapool.lua` — `ensure_imported(presetKey)` returns MediaPoolItem
- `lib/overlay.lua` — `add`, `remove`, `remove_all`, `find_all`, `set_enabled`, `toggle`

Test: from Workspace > Console (Lua mode), `require` the modules and exercise each function manually.

### Phase 2 — Entry scripts

Goal: Keyboard-mappable actions work, no GUI required.

- `SafeZone_Toggle.lua` — finds all `__SZ_*` clips, flips enabled state
- `SafeZone_Render.lua` — disables overlays, opens Deliver

User can map these to shortcuts and use the plugin headlessly.

### Phase 3 — Minimal GUI

Goal: GUI opens, shows detected ratio, has working platform buttons.

- `lib/ui.lua` — window builder
- `SafeZone.lua` — entry that opens window, runs dispatcher loop
- Status label updates on open
- Platform buttons trigger `overlay.add` with replace mode

### Phase 4 — Stack mode + ratio fallback

- Add stack mode checkbox + wire to add() mode argument
- Add ratio-only buttons row
- Footer label shows active overlays

### Phase 5 — Pre-render guard

- `lib/guard.lua` — page polling timer
- Dialog modal with `[Disable & Continue]` / `[Keep Overlay (will render)]`
- Safe Render button as primary path

### Phase 6 — Polish

- Highlight detected-ratio buttons visually
- Disable irrelevant buttons or just visually de-emphasize
- Color the timeline track / clips for visibility (`SetClipColor("Pink")` matches your accent palette)
- Update footer dynamically

### Phase 7 — Docs

- README with install instructions, screenshots, shortcut mapping guide
- Asset PNG specifications doc (so PNGs can be regenerated/customized later)

---

## 7. Edge cases

Numbered for traceability in implementation.

| # | Case | Handling |
|---|---|---|
| 1 | No project open | Show error label in GUI, disable all buttons |
| 2 | No timeline in project | Same |
| 3 | Timeline has 0 video tracks | Auto-create one |
| 4 | Top video track is locked | Try next track up; if also locked, show error |
| 5 | Detected aspect ratio doesn't match any preset | Status shows "Custom: 2.39:1" — show all buttons, no highlight |
| 6 | PNG asset file missing from bundle | Error toast, log path that's missing |
| 7 | PNG already in MediaPool | Reuse existing MediaPoolItem, don't reimport |
| 8 | User manually deleted overlay clip | `find_all()` returns empty list; toggle is no-op |
| 9 | User changes timeline resolution while overlay active | Re-open GUI re-detects and warns: "Timeline is now 16:9 but TikTok 9:16 overlay is active" |
| 10 | Timeline duration changes (clips added/removed) | Overlay clip duration is fixed at creation time; provide "Refit" button or auto-extend on focus |
| 11 | Multiple timelines in project | Operate on `GetCurrentTimeline()` only |
| 12 | User on Color/Fusion/Cut page | GUI works from any page; overlay visible in any viewer that respects timeline |
| 13 | Resolve API call returns nil/false | Every call checks return value, surfaces error to GUI footer |
| 14 | PNG dimensions don't match timeline resolution | Resolve auto-scales — design PNGs for common timeline resolutions (1080p, 4K) and accept some scaling |
| 15 | User adds clips after overlay applied | Footer warning: "Timeline extended past overlay end — click Refit" |
| 16 | Stack mode with same preset clicked twice | No-op (preset already active) |
| 17 | GUI opened twice (two windows) | Singleton: check for existing window, focus it instead of creating new |
| 18 | Keyboard customization not set up | Plugin still runs from Workspace > Scripts > Utility > SafeZone menu |
| 19 | Resolve language ≠ English | Plugin doesn't depend on menu names — should work |
| 20 | Auto-disable on Deliver dialog dismissed via X (no choice) | Treat as "Keep Overlay" (do nothing) |
| 21 | User clicks Safe Render with no overlays active | Just opens Deliver, no-op on overlays |
| 22 | Render starts via Workspace shortcut while overlay enabled | No protection possible — render-hooks don't exist. Document. |

---

## 8. Tests

### Unit tests (logic, no Resolve)

Pure-function logic isolated in `lib/presets.lua` and parts of `lib/detect.lua` can be tested with a Lua test runner (e.g. `busted`).

Tests to write:

```lua
-- presets_spec.lua
describe("presets.lookup", function()
    it("finds platform presets by key", function()
        assert.equals("TikTok", presets.lookup("tiktok_9x16").label)
    end)
    it("returns nil for unknown key", function()
        assert.is_nil(presets.lookup("nonexistent"))
    end)
end)

describe("presets.by_ratio", function()
    it("returns all presets matching a ratio", function()
        local results = presets.by_ratio("9x16")
        assert.is_true(#results >= 3)  -- TikTok, IG Reels, YT Shorts
    end)
end)

-- detect_spec.lua
describe("detect.classify_ratio", function()
    it("classifies 1080x1920 as 9x16", function()
        assert.equals("9x16", detect.classify_ratio(1080, 1920))
    end)
    it("classifies 1920x1080 as 16x9", function()
        assert.equals("16x9", detect.classify_ratio(1920, 1080))
    end)
    it("classifies 1080x1080 as 1x1", function()
        assert.equals("1x1", detect.classify_ratio(1080, 1080))
    end)
    it("classifies 1080x1350 as 4x5", function()
        assert.equals("4x5", detect.classify_ratio(1080, 1350))
    end)
    it("returns 'unknown' for non-preset ratios", function()
        assert.equals("unknown", detect.classify_ratio(1920, 800))
    end)
    it("tolerates rounding (e.g. 1079x1920)", function()
        assert.equals("9x16", detect.classify_ratio(1079, 1920))
    end)
end)
```

Run: `busted spec/`

### Integration tests (Resolve required)

Cannot be automated reliably. Use a manual test script in console.

### Manual test checklist

Before any release, run through this in Resolve with a test project:

```
INSTALL
[ ] Drop SafeZone/ folder in Scripts/Utility/
[ ] Restart Resolve
[ ] SafeZone, SafeZone_Toggle, SafeZone_Render appear in Workspace > Scripts > Utility
[ ] Map keyboard shortcuts in Keyboard Customization — they appear under "Scripts"
[ ] Map "SafeZone" to Cmd+Shift+S
[ ] Map "SafeZone_Toggle" to Cmd+Shift+H

BASIC FLOW (1080x1920 timeline)
[ ] Cmd+Shift+S opens GUI
[ ] Status reads "Detected: 9:16"
[ ] 9:16 platform buttons visually highlighted (TikTok, IG Reels, YT Shorts)
[ ] Click TikTok — overlay appears in viewer within 500ms
[ ] Footer reads "Active: TikTok"
[ ] PNG appears on new track named "SafeZone" with clip color set
[ ] Cmd+Shift+H disables overlay — viewer clean, clip still on timeline
[ ] Cmd+Shift+H again — overlay back

REPLACE BEHAVIOR
[ ] With TikTok active, click IG Reels — TikTok overlay removed, IG Reels added
[ ] Footer reads "Active: IG Reels"

STACK BEHAVIOR
[ ] Tick stack mode checkbox
[ ] Click TikTok — added to existing IG Reels
[ ] Footer reads "Active: IG Reels, TikTok" (or similar)
[ ] Toggle disables both
[ ] Toggle enables both

PRE-RENDER GUARD
[ ] With overlay enabled, click Safe Render — overlay disabled, Deliver page opens
[ ] Apply new overlay, navigate to Deliver via tab/menu — dialog appears
[ ] Choose [Disable & Continue] — overlay disabled, stays on Deliver
[ ] Re-enable overlay, navigate to Deliver, choose [Keep Overlay] — overlay stays enabled, on Deliver

EDGE CASES
[ ] No timeline — GUI shows error, buttons disabled
[ ] 4096x2160 timeline — Status "Detected: 17:9 (custom)" — all buttons available
[ ] 1920x1080 timeline — 16:9 buttons highlighted
[ ] Manually delete overlay clip, then Cmd+Shift+H — graceful, no error
[ ] Change timeline resolution mid-session — reopen GUI, see warning in status
[ ] Lock top track, apply overlay — falls to next track or errors gracefully
[ ] Close GUI, reopen — singleton: focuses existing or recreates cleanly
[ ] Stack 3 overlays, remove_all — all cleared

UNINSTALL
[ ] Remove plugin folder, restart Resolve
[ ] Keyboard shortcuts gracefully orphaned (no crash)
[ ] Existing overlay clips remain on timelines (work without plugin since they're just PNGs)
```

---

## 9. PNG asset specifications

All PNGs are RGBA, designed for the **target output resolution** of each ratio so they scale cleanly:

| Asset | Resolution | Layout |
|---|---|---|
| `frame_9x16.png` | 1080×1920 | Just the 9:16 frame outline + semi-transparent fill outside if used in 16:9 timeline |
| `frame_16x9.png` | 1920×1080 | 16:9 frame |
| `frame_1x1.png` | 1080×1080 | Square frame |
| `frame_4x5.png` | 1080×1350 | Portrait frame |
| `frame_4x3.png` | 1440×1080 | Classic frame |
| `tiktok_9x16.png` | 1080×1920 | Top safe ~150px, bottom safe ~480px, right side ~200px (action bar zone) |
| `ig_reels_9x16.png` | 1080×1920 | Top safe ~220px, bottom safe ~370px, right ~180px |
| `yt_shorts_9x16.png` | 1080×1920 | Top safe ~120px, bottom safe ~340px, right ~150px |
| `ig_feed_4x5.png` | 1080×1350 | Top/bottom ~60px |
| `ig_post_1x1.png` | 1080×1080 | All edges ~40px |
| `yt_16x9.png` | 1920×1080 | Title safe 10%, action safe 5% |

### Visual design

Follow Stephan's design preferences:
- **Outline color:** cyan (#22D3EE) or magenta (#EC4899) — high contrast against most footage
- **Style:** sharp corners (technical), 2-3px stroke
- **Outside-safe-zone fill:** 25-35% black at the same color as outline for tinted overlay (or no fill, just outline — verify which reads better)
- **Labels:** small text in corners identifying platform + zone (e.g. "TikTok — action bar"), monospace
- **Avoid:** grey minimalism, corporate blue
- **No filler text** — only functional labels

Platform UI safe zone numbers should be **verified against current platform specs** (TikTok / IG / YT change these over time). Source for v1: cross-reference [https://novustools.com/davinci-resolve-safe-zone/](https://novustools.com/davinci-resolve-safe-zone/) and the platforms' own creator docs as of build time.

### Generation approach

Hand-design in Figma/Affinity → export as PNG. Alternatively, generate programmatically with a small Python script using Pillow, kept in `tools/` for reproducibility:

```python
# tools/generate_assets.py
# Takes a JSON config of zones per platform, outputs PNGs
```

Programmatic approach is preferred — easier to update when platform UIs change.

---

## 10. Install & user docs

### Installation

```bash
# macOS
cp -r SafeZone ~/Library/Application\ Support/Blackmagic\ Design/DaVinci\ Resolve/Fusion/Scripts/Utility/

# Restart DaVinci Resolve
```

**Windows path:**
`%APPDATA%\Blackmagic Design\DaVinci Resolve\Support\Fusion\Scripts\Utility\`

**Linux path:**
`~/.local/share/DaVinciResolve/Fusion/Scripts/Utility/`

### Setting up keyboard shortcuts

1. DaVinci Resolve > Keyboard Customization (or Cmd+Option+K)
2. Search for "SafeZone" in the right-hand search field
3. Three actions appear:
   - **SafeZone** — opens the GUI
   - **SafeZone_Toggle** — toggles overlay enabled state
   - **SafeZone_Render** — safe path to render (disable overlay + open Deliver)
4. Click the keyboard column next to each, press desired combo, hit Save
5. Suggested defaults (not enforced):
   - SafeZone → Cmd+Shift+S
   - SafeZone_Toggle → Cmd+Shift+H
   - SafeZone_Render → (optional, no default — most will use the GUI button)

### Daily use

1. Hit your "open" shortcut → GUI floats up
2. Glance at "Detected: 9:16" — confirms timeline ratio
3. Click your platform (TikTok / IG Reels / YT Shorts) → overlay appears
4. Frame your shot
5. Toggle on/off with your toggle shortcut as needed
6. When ready to render, click "Safe Render" in the GUI
7. Or just navigate to Deliver — guard dialog catches you

---

## 11. Open questions / verify during build

Things flagged in this plan that should be confirmed before or during implementation:

1. **`clipInfo` table schema for `AppendToTimeline`** — verify exact field names against installed Resolve version's `README.txt`. Plan assumes `mediaPoolItem`, `startFrame`, `endFrame`, `recordFrame`, `trackIndex`, `mediaType`.

2. **Modifier key detection in UI Manager button events** — confirm whether `ev.modifiers` is populated. Fallback to stack-mode checkbox is already planned.

3. **Whether `SetClipColor` syntax is correct** — verify color name strings against current Resolve.

4. **Whether `GetTrackName` / `SetTrackName` / `GetIsTrackLocked` exist on Timeline** — these may have changed signatures.

5. **Plugin name** — `SafeZone` is a working title. Suggestions to consider:
   - `Beacon` (lighthouse → guidance) — fits your naming style
   - `Bracket` (literal framing)
   - `Edges`
   - `Aperture`
   - `Marker` (probably too generic / taken)
   - `Zonum` (made-up, brandable)

6. **Should `SafeZone_Render` exist as a separate keyboard-mappable script** in addition to the in-GUI button? It's listed in install docs but adds maintenance. Decide before Phase 2.

7. **PNG dimensions** — design for highest common timeline resolution (4K) and accept downscale, or design per common resolution? Affects asset bundle size.

8. **License + repo structure** — assume new repo, so initial commit is the only one without a PR per your standard workflow.

---

## 12. Out of scope for v1 (parking lot)

- User-uploaded custom PNGs
- Per-project preferences (which platforms to show)
- Auto-removal of overlay clips before render (would need render-hook API)
- Cross-platform path resolution beyond the documented defaults
- Custom outline colors per project
- Persistent state (last selected platform on reopen)
- Localization (Norwegian UI)
- Cinematic ratio frames (2.35, 2.39, 1.85)
- Integration with existing MonoForge workflow

These belong in v2.
