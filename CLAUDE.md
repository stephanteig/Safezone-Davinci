# CLAUDE.md — SafeZone DaVinci Resolve Plugin

**Auto-loaded by Claude Code each session. This is the single source of truth for project context, architecture decisions, edge cases, and known API quirks. Read in full before writing any code.**

---

## Project status

All 6 build phases complete as of 2026-05-28. Plugin is installed and ready for integration testing.

| Phase | Description | Status |
|---|---|---|
| 1 | Foundation — core.lua, presets.lua, detect.lua, mediapool.lua, overlay.lua | Complete |
| 2 | Entry scripts — SafeZone.lua, SafeZone_Toggle.lua, SafeZone_Render.lua | Complete |
| 3 | Minimal GUI — ui.lua with all buttons, status label, footer | Complete |
| 4 | Stack mode + ratio fallback | Complete |
| 5 | Pre-render guard — guard.lua with 500ms page-poll timer | Complete |
| 6 | Polish — button highlighting, dynamic footer, clip color | Complete |

**What is NOT yet done (next work):**
- PNG overlay assets in `SafeZone/assets/` — not created yet; plugin will error on first button click until these exist
- `TESTING.md` — manual integration test checklist referenced in plan but not yet written

---

## Repository layout

```
SafeZone/
  SafeZone.lua          — entry: sets package.path, calls ui.open()
  SafeZone_Toggle.lua   — headless toggle (keyboard shortcut)
  SafeZone_Render.lua   — headless safe-render (keyboard shortcut)
  assets/               — PNG overlays (NOT YET CREATED — see §Assets below)
    platform/
      tiktok_9x16.png
      ig_reels_9x16.png
      yt_shorts_9x16.png
      ig_feed_4x5.png
      ig_post_1x1.png
      yt_16x9.png
      x_twitter_16x9.png
    ratio/
      frame_9x16.png
      frame_4x5.png
      frame_1x1.png
      frame_4x3.png
      frame_16x9.png
  lib/
    presets.lua   — pure data; all 12 overlay presets; no Resolve dependency
    detect.lua    — ratio classification; pure classify_ratio() + Resolve-aware detect_ratio()
    core.lua      — lazy-init Resolve handle getters
    mediapool.lua — PNG import/dedup into SafeZone MediaPool bin
    overlay.lua   — full overlay lifecycle (find, add, remove, toggle, enable/disable)
    ui.lua        — Fusion UI Manager window; event wiring; singleton guard
    guard.lua     — 500ms page-poll timer; shows modal when user navigates to Deliver
spec/
  presets_spec.lua  — 17 busted tests for presets.lua
  detect_spec.lua   — 14 busted tests for detect.classify_ratio()
check.sh            — syntax check via fuscript (NOT luac — luac is not installed)
install.sh          — symlinks SafeZone/ into Resolve's Utility scripts folder
```

---

## Stack and environment

- **Language:** Lua 5.1-compatible. Resolve embeds a LuaJIT-based runtime. Do not use Lua 5.2+ syntax.
- **GUI:** Fusion UI Manager — `fu.UIManager`, `bmd.UIDispatcher`. No external deps.
- **Test runner:** `busted` (dev only). Installed via Homebrew + LuaRocks. The dev machine runs Lua 5.5.0 (Homebrew), not 5.1, but busted works for pure-logic tests.
- **Syntax checker:** `fuscript` at `/Applications/DaVinci Resolve/DaVinci Resolve.app/Contents/Libraries/Fusion/fuscript`. `luac` is NOT installed on the dev machine. `check.sh` uses fuscript.
- **Resolve version tested:** 21.0.0 on macOS.
- **API reference:** `~/Library/Application Support/Blackmagic Design/DaVinci Resolve/Developer/Scripting/README.txt` — **this file does NOT exist on the dev machine** (Resolve 21.0.0 didn't create it). All API calls are based on training-data knowledge of Resolve 17–21.

---

## Commands

```bash
./check.sh          # Syntax check all .lua files (uses fuscript, not luac)
busted spec/        # Run unit tests (31 tests, all green)
./install.sh        # Symlink SafeZone/ into Resolve's Scripts/Utility/ (macOS)
```

Run `check.sh` and `busted spec/` after every code change. Both must pass before committing.

---

## Architecture — critical rules

### State model
All plugin state lives on the timeline. Overlay clips are named with the `__SZ_` prefix (`CLIP_PREFIX` in overlay.lua). `find_all()` scans all video tracks for this prefix. **Never write external config files, project metadata, or hidden files.** If `SetProperty("Clip Name", ...)` fails on a placed clip (VERIFY item — see below), `find_all()` will not identify that clip and toggle/remove operations will miss it.

### Lazy-init Resolve handles
Never call `Resolve()` at module load time. The global may not be injected until the script is actively running inside Resolve. All handle getters (`get_resolve()`, `get_project()`, `get_timeline()`, `get_media_pool()`) are in `core.lua` and called inside functions. They all return `(value, errmsg)` — always check for nil.

### require() path
Entry scripts (`SafeZone.lua`, `SafeZone_Toggle.lua`, `SafeZone_Render.lua`) prepend `plugin_root/lib/?.lua` to `package.path`. Internal requires use **simple names only**:
```lua
require("core")      -- correct
require("presets")   -- correct
require("overlay")   -- correct

require("SafeZone.lib.core")   -- WRONG — this path is never on package.path
require("lib.core")            -- WRONG
```
This was a critical bug discovered during Phase 2. Do not revert.

### detect.lua loads core lazily
`detect.lua` loads `core` inside `detect_ratio()` via `local core = require("core")`, not at the module top level. This avoids a circular dependency chain at load time. `classify_ratio()` is pure and does not require core — this split is intentional and must be preserved to keep the function unit-testable.

### Modal dialogs
Fusion UI Manager has no native modal support. `guard.lua` implements a blocking dialog using a nested `disp:RunLoop()` — the inner loop runs inside the timer callback, which runs inside the outer `RunLoop()` in `ui.lua`. This is the standard Fusion UI Manager modal pattern.

### Timer lifecycle
Every `_timer:Start()` in `guard.lua` must be paired with a `_timer:Stop()` in the main window's close handler. The close handler calls `guard.stop()` before `disp:ExitLoop()`. Failure to stop the timer before exiting the loop leaves a dangling callback.

### Singleton GUI
`M.open()` in `ui.lua` uses `fu:GetData("SafeZone.IsOpen")` as a best-effort singleton flag. Cleared in the close handler via `fu:SetData(SINGLETON_KEY, nil)`. If Resolve crashes while the GUI is open, the flag stays set — the user must restart Resolve (acceptable one-time annoyance, not a fixable bug).

---

## File-by-file summary

### `lib/presets.lua`
Pure data module — no Resolve dependency, fully unit-testable. 12 presets total: 7 platform presets + 5 ratio-only presets. Each preset has: `key` (unique string), `label` (display name), `ratio` (e.g. "9x16"), `category` ("platform" or "ratio"), `asset` (relative path from `SafeZone/assets/`), `clip_name_prefix` (the `__SZ_*` name used on the timeline clip). Internal `_by_key` table built at load time for O(1) lookup. Exports: `lookup(key)`, `by_ratio(ratio)`, `all()`.

### `lib/detect.lua`
Two-part module. `classify_ratio(w, h)` is pure: takes pixel dimensions, applies ±2px tolerance, returns ratio key or "unknown". `detect_ratio()` reads `timeline:GetSetting("timelineResolutionWidth/Height")` and calls classify_ratio. Returns `(ratioKey, w, h)` or `("unknown", nil, nil)`. The `nil, nil` on w/h is the signal used by `refresh_ui()` in ui.lua to detect "no timeline" state.

### `lib/core.lua`
All Resolve handle getters. `get_resolve()` uses `pcall(Resolve)` for safety. Chain: resolve → project manager → current project → current timeline / media pool. `plugin_root()` uses `debug.getinfo(1, "S").source` to derive the absolute path to `SafeZone/` from the path of `core.lua` itself — used by mediapool.lua to build asset paths.

### `lib/mediapool.lua`
`ensure_imported(preset_key)`: finds or creates a "SafeZone" bin in the MediaPool root folder. Deduplicates by checking `folder:GetClipList()` for a clip named `clip_name_prefix`. If not found, resolves the asset path via `plugin_root()`, checks file existence with `io.open()`, calls `mp:SetCurrentFolder(bin)` then `mp:ImportMedia({path})`, then renames via `item:SetClipProperty("Clip Name", clip_name)` (VERIFY — see below).

### `lib/overlay.lua`
Full overlay lifecycle. Key constants: `CLIP_PREFIX = "__SZ_"`, `TRACK_NAME = "SafeZone"`, `OVERLAY_COLOR = "Pink"`. `find_all()` iterates all video tracks. `add(preset_key, mode)`: handles "replace" vs "stack" mode, calls mediapool.ensure_imported(), calls `get_overlay_track()` (finds/creates SafeZone track), computes duration from `timeline:GetEndFrame() - timeline:GetStartFrame()`, calls `mp:AppendToTimeline({clipInfo})`, then names the clip and sets color. `remove_all()` calls `timeline:DeleteClips(to_delete)` with all clips in one call.

### `lib/ui.lua`
Full Fusion UI Manager window. `PLATFORM_BUTTONS` and `RATIO_BUTTONS` tables each have `id`, `key`, and `text` fields — `text` is the button display string (e.g. "X" for the X/Twitter button, which differs from its preset label "X / Twitter"). `refresh_ui(itms)` calls detect, updates status label, enables/disables all `ACTION_BUTTON_IDS`, calls `update_button_highlights()`, and calls `set_footer(get_overlay_status())`. Button matching uses `◆ ` (UTF-8 `\xe2\x97\x86 `) prefix prepended to button text — no color API, just text prefix, for maximum portability across Resolve versions. Window geometry: `{100, 100, 380, 560}`.

### `lib/guard.lua`
Module-level `_timer` and `_last_page`. `start(disp, on_disable_cb)`: captures current page first (so first tick doesn't false-fire if already on Deliver), creates 500ms timer on `fu.UIManager`, timer callback watches for "deliver" page transitions with any overlay enabled. `show_guard_dialog()` uses nested `disp:RunLoop()` for modal behavior. Default choice is `"keep"` — X button and close both result in no state change (safe default per §7.20). `stop()` must be called in main window close handler.

### Entry scripts
Each sets `package.path = plugin_root .. "/lib/?.lua;" .. package.path` using `debug.getinfo(1, "S").source` to derive the root. `SafeZone.lua` → `ui.open()`. `SafeZone_Toggle.lua` → checks timeline exists, calls `overlay.toggle()`. `SafeZone_Render.lua` → `overlay.set_enabled(false)`, then `resolve:OpenPage("deliver")`.

---

## VERIFY items — unconfirmed API calls

These were marked `-- VERIFY` during build because the Resolve API reference was unavailable. **Test each at runtime in Resolve before modifying the calling code.** If a call fails at runtime, the section below documents the likely fallback.

| Call | File | Risk | Fallback if it fails |
|---|---|---|---|
| `timeline:GetIsTrackLocked("video", i)` | overlay.lua:94 | Medium | Try `IsTrackLocked` (no "Get" prefix). If neither works, remove the locked-track check and document the limitation. |
| `timeline:DeleteClips({item})` | overlay.lua:136, 154 | High | Try `timeline:DeleteClipsByVideoTrack()` or `timeline:DeleteTimelineItems()`. If none work, remove_all may need to iterate and delete one by one. |
| `placed:SetProperty("Clip Name", prefix)` | overlay.lua:232 | **CRITICAL** | If this fails, `find_all()` cannot identify placed clips. Fallback: try `placed:GetMediaPoolItem():GetName()` to read the media pool item name, and change `is_overlay()` to match against that instead. This would mean the `__SZ_` prefix must be set on the MediaPoolItem, not the TimelineItem. |
| `item:SetClipProperty("Clip Name", name)` | mediapool.lua:99 | Low | Non-fatal if this fails — dedup will re-import next time, which is wasteful but harmless. |
| `mediaType = 1` in clipInfo | overlay.lua:219 | Low | Field may be silently ignored on some Resolve versions. If AppendToTimeline fails, try omitting it. |

**If `SetProperty("Clip Name", ...)` (the CRITICAL one) fails at runtime**, the entire state model breaks. The fix requires switching from timeline-clip-name identification to a different anchor (e.g. matching clip color + position, or using a hidden project note). This is the highest-priority item to verify during integration testing.

---

## Edge cases — implementation map

All 22 edge cases from `SAFEZONE_PLAN.md §7`, with implementation locations:

| # | Case | Handled in | How |
|---|---|---|---|
| 7.1 | No project open | core.lua:get_project | Returns `(nil, errmsg)`; ui.lua disables all buttons |
| 7.2 | No timeline open | core.lua:get_timeline | Returns `(nil, errmsg)`; `detect_ratio` returns `nil` w/h; `refresh_ui` shows "No timeline open" |
| 7.3 | No video tracks | overlay.lua:get_overlay_track | Calls `timeline:AddTrack("video")` to create one |
| 7.4 | SafeZone track is locked | overlay.lua:get_overlay_track | Skips locked tracks; creates a new track; errors if AddTrack fails (VERIFY: GetIsTrackLocked) |
| 7.5 | Asset PNG missing | mediapool.lua:ensure_imported | `io.open()` checks existence before ImportMedia; returns `(nil, "Asset file not found: …")` |
| 7.6 | Asset file exists check | mediapool.lua:ensure_imported | Same as 7.5 — `io.open(path, "rb")` check |
| 7.7 | Re-clicking same platform | mediapool.lua:ensure_imported | Deduplication via `find_clip_in_folder()` before ImportMedia |
| 7.8 | User manually deleted clip | overlay.lua:find_all | Returns `{}`; toggle is a no-op; footer shows "No overlays active" |
| 7.9 | Timeline has zero duration | overlay.lua:add | Checks `duration <= 0` explicitly; returns error |
| 7.10 | Timeline grows after overlay placed | overlay.lua:add | Overlay is placed for full duration at apply time only; no live resize |
| 7.11 | Multiple timelines | overlay.lua:find_all | Always operates on `GetCurrentTimeline()` — whichever is active |
| 7.12 | Resolve not running | core.lua:get_resolve | `pcall(Resolve)` catches the error |
| 7.13 | SetClipEnabled fails | overlay.lua:set_enabled | Returns `(false, errmsg)` naming the clip |
| 7.14 | AppendToTimeline returns empty | overlay.lua:add | Explicit `#new_items == 0` check; returns error |
| 7.15 | Overlay placed at wrong position | overlay.lua:add | `recordFrame = timeline:GetStartFrame()` ensures it starts at timeline beginning |
| 7.16 | Stack mode duplicate | overlay.lua:add | Scans existing clips for matching prefix; returns early if found |
| 7.17 | GUI opened twice | ui.lua:M.open | `fu:GetData("SafeZone.IsOpen")` singleton check |
| 7.18 | Close button with timer running | ui.lua:wire_events | `guard.stop()` called first in close handler before `ExitLoop()` |
| 7.19 | Guard fires while dialog open | guard.lua:_timer.On.Timeout | Timer is stopped before `show_guard_dialog()`, restarted after it returns |
| 7.20 | Guard dialog dismissed via X | guard.lua:show_guard_dialog | `choice` defaults to `"keep"`; X close handler calls `ExitLoop()` without changing choice |
| 7.21 | Safe Render with no overlays | overlay.lua:set_enabled | `find_all()` returns `{}`; loop body never executes; returns `(true, nil)` |
| 7.22 | Native render shortcut while GUI closed | Not addressable by API | Documented in README.md — no Resolve render hook exists in scripting API |

---

## Known API quirks and decisions

### Still image duration in AppendToTimeline
`GetClipProperty("Frames")` does NOT work for this. The correct approach is:
```lua
local start_frame = timeline:GetStartFrame()
local end_frame   = timeline:GetEndFrame()
local duration    = end_frame - start_frame
-- clipInfo: startFrame=0, endFrame=duration, recordFrame=start_frame
```
`startFrame` and `endFrame` in clipInfo refer to the source (still image) in/out points. `recordFrame` is the timeline insert position. For a still image held for `N` frames: `startFrame=0`, `endFrame=N`, `recordFrame=timeline_start`.

### detect_ratio returns nil w/h for "no timeline"
`refresh_ui()` uses `w ~= nil` (not `ratio ~= "unknown"`) to detect whether a timeline is open, because a custom resolution returns `ratio="unknown"` but still has valid `w` and `h`. Checking `w` preserves this distinction.

### X/Twitter button text vs preset label
The button in the GUI shows "X" but the preset label is "X / Twitter". The `PLATFORM_BUTTONS` table has a `text` field to store the button display string independently. `update_button_highlights()` restores to `btn_def.text` (not `preset.label`) when clearing the highlight marker.

### fuscript syntax check
`check.sh` runs fuscript on each `.lua` file and greps for "syntax error", "unexpected symbol", "<eof>" in the output. This is necessary because `luac` is not installed on the dev machine. fuscript is Resolve's embedded Lua interpreter at `/Applications/DaVinci Resolve/DaVinci Resolve.app/Contents/Libraries/Fusion/fuscript`.

### .gitignore lib/ conflict
The repo used a Python `.gitignore` template that ignores `lib/` globally. Fixed by adding `!SafeZone/lib/` immediately after the `lib/` and `lib64/` lines in `.gitignore` (order matters — the negation must come after the ignore pattern it overrides).

### Fusion UI Manager button highlighting
Fusion's button colour/style API varies across Resolve versions and is not reliably documented. Text-prefix markers (`◆ `) are the most portable approach. The diamond `◆` (U+25C6, UTF-8 `\xe2\x97\x86`) is compact and renders in Resolve's default UI font without emoji fallback issues.

---

## Assets — what needs to be created

The plugin will crash with "Asset file not found" when any platform/ratio button is clicked until the PNG files are created. All PNGs must be RGBA (transparent background with safe zone frame drawn over it), at the resolutions listed below.

| Preset key | Asset path | Dimensions |
|---|---|---|
| tiktok_9x16 | assets/platform/tiktok_9x16.png | 1080×1920 |
| ig_reels_9x16 | assets/platform/ig_reels_9x16.png | 1080×1920 |
| yt_shorts_9x16 | assets/platform/yt_shorts_9x16.png | 1080×1920 |
| ig_feed_4x5 | assets/platform/ig_feed_4x5.png | 1080×1350 |
| ig_post_1x1 | assets/platform/ig_post_1x1.png | 1080×1080 |
| yt_16x9 | assets/platform/yt_16x9.png | 1920×1080 |
| x_twitter_16x9 | assets/platform/x_twitter_16x9.png | 1920×1080 |
| ratio_9x16 | assets/ratio/frame_9x16.png | 1080×1920 |
| ratio_4x5 | assets/ratio/frame_4x5.png | 1080×1350 |
| ratio_1x1 | assets/ratio/frame_1x1.png | 1080×1080 |
| ratio_4x3 | assets/ratio/frame_4x3.png | 1440×1080 |
| ratio_16x9 | assets/ratio/frame_16x9.png | 1920×1080 |

Platform presets should show the platform-specific UI safe zone (e.g. TikTok's top/bottom UI bars, button areas). Ratio presets are a simple crop frame (1–3px border at the ratio boundaries, rest transparent). See `SAFEZONE_PLAN.md §9` for full asset specifications.

---

## Test results (as of last run)

```
busted spec/   →  31 tests, 0 failures, 0 errors
./check.sh     →  12 files passed, 0 failed
```

Tests cover:
- `presets.lua`: lookup by key, nil/empty/unknown key handling, by_ratio filtering, all() returns 12, mutations don't affect internal table, all keys unique, all clip_name_prefixes unique, all required fields present and typed correctly
- `detect.classify_ratio()`: canonical portrait/landscape/square resolutions, 4K variants, ±2px tolerance (in-range and out-of-range), custom ratios return "unknown", zero/nil/negative inputs return "unknown"

Tests do NOT cover: `detect_ratio()`, `core.*`, `mediapool.*`, `overlay.*`, `ui.*`, `guard.*` — all require Resolve runtime.

---

## Code style

- 4-space indent throughout
- `local` everything; exports via explicit `M.function_name = function(…)`
- One module per file; `return M` at the bottom
- `snake_case` for all function and variable names
- Module name matches filename: `lib/overlay.lua` → `require("overlay")`
- Error return pattern: `(value, errmsg)` where value is nil/false on failure
- Inline comments only for non-obvious logic. Edge case references use `-- §7.N` format.
- No globals beyond Resolve's auto-injected: `Resolve`, `fu`, `bmd`, `app`

---

## Design preferences (GUI)

- Accent palette: cyan, violet, scarlet, magenta/pink, pastels
- Sharp corners — technical feel, not friendly or rounded
- Dark UI default
- Mix sans UI with editorial italic serif display where applicable
- Borders on controls, shadows on cards
- Avoid: grey minimalism, corporate blue, filler copy, cramped margins

---

## Workflow

- All changes after initial commit: feature branch → PR → review → merge
- No force push, no history rewriting
- Run `check.sh` and `busted spec/` before every commit
- Co-author Claude commits with `Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>`

---

## Anti-patterns (discovered during build — do not repeat)

- **`require("SafeZone.lib.core")`** — breaks at runtime. Use `require("core")` inside lib files.
- **`GetClipProperty("Frames")`** — returns nil for still images. Use timeline start/end frame calculation.
- **Calling `Resolve()` at module top level** — the global may not exist at require time.
- **Not stopping the timer before `ExitLoop()`** — leaves a dangling timer callback.
- **Checking `ratio ~= "unknown"` to detect "no timeline"** — custom resolutions return "unknown" but a timeline is open. Check `w ~= nil` instead.
- **`luac -p` in check.sh** — luac is not installed. Use fuscript.
- **`git add SafeZone/lib/` without the `!SafeZone/lib/` negation in .gitignore** — Python gitignore template blocks the lib/ directory globally.

---

## Reference docs

- Canonical spec: `SAFEZONE_PLAN.md`
- Build instructions: `CLAUDE_CODE_INSTRUCTIONS.md`
- User docs: `README.md`
- This file: session context, implementation decisions, API quirks
