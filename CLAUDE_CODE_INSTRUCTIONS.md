# CLAUDE_CODE_INSTRUCTIONS.md

Briefing for Claude Code to build the SafeZone DaVinci Resolve plugin. Built on the 4-part prompt formula (Role + Objective + Context + Constraints), Plan Mode workflow, evidence-based completion, and project conventions (CLAUDE.md).

> **Spec doc:** All "what to build" details live in `SAFEZONE_PLAN.md`. This doc covers "how to build it." Read both before writing any code.

---

## 1. Role

> Act as a **Senior Lua plugin developer specializing in DaVinci Resolve scripting and Fusion UI Manager**. You have 5+ years of experience writing production tools for video editors, including familiarity with the Resolve scripting API quirks across versions 18-20. You write defensive, observable code — never optimistic. You verify API behavior against the official `README.txt` before using any call you haven't used in this session.

---

## 2. Objective

> Build the SafeZone plugin as specified in `SAFEZONE_PLAN.md`, in phases, with verifiable evidence after each phase. The single most important success criterion: an editor with the plugin installed can frame social media content with safe-zone overlays and cannot accidentally render those overlays into a client deliverable (without explicit bypass).

---

## 3. Exact Context

### Files and paths

- **Canonical spec:** `SAFEZONE_PLAN.md` (sibling to this file). Read fully before writing code. Cite section numbers when implementing (e.g. "implementing §6 Phase 2").
- **DaVinci scripting API reference:** `~/Library/Application Support/Blackmagic Design/DaVinci Resolve/Developer/Scripting/README.txt` on the developer's macOS machine. This is the authoritative API source — verify field names, method signatures, and return types against this file. Plan doc API references may be stale.
- **Plugin install path (macOS):** `~/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts/Utility/`
- **Plugin install path (Windows):** `%APPDATA%\Blackmagic Design\DaVinci Resolve\Support\Fusion\Scripts\Utility\`
- **Plugin install path (Linux):** `~/.local/share/DaVinciResolve/Fusion/Scripts/Utility/`

### Stack

- **Language:** Lua (Resolve embeds Lua 5.1-compatible runtime; do not use 5.2+ syntax)
- **GUI framework:** Fusion UI Manager (`fu.UIManager`, `bmd.UIDispatcher`) — built into Resolve, no external deps
- **Dependencies:** zero external Lua deps for runtime. `busted` is allowed for unit tests in `spec/` only.
- **Target OS:** macOS primary (developer environment). Windows/Linux paths documented but untested.

### What's been decided (locked)

See `SAFEZONE_PLAN.md` §2. Summary:

- Safe zone style: platform-specific as default, ratio-only as fallback
- Pre-render guard: max paranoid with bypass (Render button + Deliver-navigation dialog with `[Disable & Continue]` / `[Keep Overlay]`)
- Multi-overlay: replace by default, Shift+click or "Stack mode" checkbox to stack

Do not relitigate these. If the implementation surfaces a reason to revisit, surface it as a question — do not silently choose differently.

---

## 4. Constraints

### Do

- Read `SAFEZONE_PLAN.md` end-to-end before writing any code
- Enter Plan Mode (Shift+Tab) before each implementation phase
- Verify every Resolve API call against the installed `README.txt` before first use
- Use `TimelineItem:SetClipEnabled(bool)` for toggles — never add/remove for toggling
- Lazy-init Resolve handles (don't call `Resolve()` at module load time; call inside functions)
- Check every Resolve API return value (`nil`, `false`, empty table) and surface to user
- Name overlay clips with the `__SZ_` prefix per spec for findability
- Bundle PNGs as RGBA at the recommended target resolutions (see `SAFEZONE_PLAN.md` §9)
- Follow Stephan's design preferences in the GUI: cyan/magenta accents, sharp corners, dark, no corporate blue, no grey minimalism, mixed sans + editorial italic serif where possible
- Use PRs for all changes after the initial commit (initial commit is exempt per Stephan's workflow)
- Create a `CLAUDE.md` at the repo root per the template in §11

### Do not

- Use Fusion compositions (explicitly rejected by the user — three times in the spec discussion)
- Use external state files, project metadata writes, or hidden config — all state lives on the timeline
- Add Lua dependencies beyond the standard library + Resolve + UI Manager
- Shell-out via `os.execute` for anything — cross-platform paths are too fragile
- Mock the Resolve API in unit tests — keep Resolve-dependent code separate from pure-logic modules, and only unit-test the pure-logic modules
- Leave `TODO` comments in committed code — surface as questions instead
- Force push, rewrite history, or skip PR review on non-initial commits
- Auto-disable overlays without offering bypass — the bypass is a locked design decision
- Touch anything outside the `SafeZone/` directory unless explicitly asked

---

## 5. Workflow (Plan Mode required)

Do not write any code until step 3.

### Step 1 — Explore

- Read `SAFEZONE_PLAN.md` in full
- Read `README.txt` (the Resolve API doc on disk) — at minimum the sections on Project, Timeline, MediaPool, TimelineItem, and UI Manager
- Verify the assumptions in `SAFEZONE_PLAN.md` §11 (Open Questions) against the actual API
- Confirm `clipInfo` field names for `mediaPool:AppendToTimeline`
- Note any discrepancies between the plan and the installed API

### Step 2 — Plan

- Enter Plan Mode (Shift+Tab)
- Outline the file tree you'll create (must match `SAFEZONE_PLAN.md` §3)
- Outline Phase 1's implementation order
- Surface any blocking questions from Step 1
- Wait for user confirmation before writing code

### Step 3 — Implement (phase by phase)

Implement in the order defined in `SAFEZONE_PLAN.md` §6:

1. Phase 1 — Foundation (no UI)
2. Phase 2 — Entry scripts
3. Phase 3 — Minimal GUI
4. Phase 4 — Stack mode + ratio fallback
5. Phase 5 — Pre-render guard
6. Phase 6 — Polish
7. Phase 7 — Docs

After each phase: stop, provide evidence (§10), wait for user to advance.

### Step 4 — Re-plan between phases

Before each subsequent phase, re-enter Plan Mode to outline what changes. Surface any new questions or API discoveries.

### Step 5 — Verify

Produce all evidence per §10 before declaring the build complete.

---

## 6. Goal

Reproduced inline so it's first-class in this doc; canonical version is `SAFEZONE_PLAN.md` §1.

Give editors a one-click way to see platform-specific safe zones (TikTok UI, IG Reels UI, etc.) and pure aspect ratio crop frames in the DaVinci viewer, with hotkey toggles and protection against accidentally rendering the overlay into a deliverable. Auto-detect the timeline's aspect ratio and highlight relevant options. Keep latencies tight: GUI open < 200ms, overlay apply < 500ms, toggle < 100ms.

---

## 7. Edge Cases

All 22 edge cases listed in `SAFEZONE_PLAN.md` §7 must be handled in code. For each:

- Either an explicit code branch (with a comment referencing the case number: `-- §7.4: top track locked`)
- Or a unit test in `spec/` covering it (with the same comment)
- Or both

**Do not skip any.** If an edge case turns out to be impossible to reach with the API as built (e.g. one fold of #11 multi-timeline), document why in a comment and surface it in the final evidence report.

Critical ones to verify hands-on:

- §7.1, §7.2 — no project / no timeline → GUI must open cleanly and disable buttons, not crash
- §7.8 — user manually deleted overlay clip → toggle is a no-op, not an error
- §7.17 — GUI opened twice → singleton: focus existing or recreate cleanly
- §7.20 — guard dialog dismissed via X → defaults to "Keep Overlay" (safe default = don't change user state)
- §7.22 — render via native shortcut while overlay enabled → no protection possible, document in README

---

## 8. Tests

Strategy reproduced from `SAFEZONE_PLAN.md` §8. Evidence requirements added.

### Unit tests (required, automated)

Tests live in `spec/`, run via `busted`. Test only the pure-logic modules:

- `presets.lua` — lookup, by_ratio filtering
- `detect.lua` — `classify_ratio(w, h)` for all preset ratios + edge cases (off-by-one, unknown)

Do not unit-test modules that wrap Resolve API calls. Mocking the Resolve global would test the mock, not the plugin.

Coverage target: 100% of branches in `presets.lua` and `detect.lua`.

### Integration tests (manual)

Cannot be automated. Produce a `TESTING.md` in the repo root containing the manual checklist from `SAFEZONE_PLAN.md` §8 verbatim, formatted for paste-into-checklist use.

### Syntax check (required, automated)

Every `.lua` file must pass `luac -p` (parse-only). Add a `check.sh` script at repo root that runs `luac -p` over every `.lua` file and exits non-zero on any failure.

---

## 9. Documentation

Deliverables required:

1. **`README.md`** at repo root — install instructions (all three OSes), keyboard shortcut setup, daily-use flow, troubleshooting (per `SAFEZONE_PLAN.md` §10)
2. **`TESTING.md`** at repo root — manual test checklist (per §8 above)
3. **`CLAUDE.md`** at repo root — project conventions (template in §11 below)
4. **Inline comments** — only for non-obvious logic. No restating-the-code comments. Edge case branches must reference `SAFEZONE_PLAN.md §7.N` by number.
5. **Updates to `SAFEZONE_PLAN.md` §11 Open Questions** — as each is resolved during implementation, update with the resolution.

Do not generate JSDoc-style headers, "author" tags, or `@param` blocks for Lua. Lua tooling doesn't use them and they're noise.

---

## 10. Evidence of Success

After each phase, do not say "done." Instead, produce:

### After every phase

- `find SafeZone -type f | sort` — full file tree of what was created/modified this phase
- For each `.lua` file touched this phase: `luac -p path/to/file.lua` output (silent = pass)
- A 1-sentence summary per file: "What this file does"
- Which edge cases from `SAFEZONE_PLAN.md` §7 this phase addressed (by number)

### After Phase 1 specifically

- `busted spec/` full terminal output (all green)
- Read-back of `lib/core.lua` and `lib/presets.lua` in full so user can verify style

### After Phase 5 specifically

- Walk through the pre-render guard flow in pseudo-code, naming the API calls
- Confirm the "guard only runs while GUI is open" caveat is documented in `README.md`

### Before declaring the build complete

- All 22 edge cases mapped to either a code branch or a unit test (table: edge case # → file:line or test name)
- `check.sh` runs clean
- `busted spec/` runs clean
- `TESTING.md` exists and matches `SAFEZONE_PLAN.md` §8
- `CLAUDE.md` exists and matches the §11 template
- `SAFEZONE_PLAN.md` §11 Open Questions section has each item marked resolved or deferred (with reason)
- A `git log --oneline` showing the commit history (one commit per phase, plus PR merge commits where applicable)

Do not skip evidence to save tokens. If something can't be produced (e.g. you don't have shell access), say so explicitly.

---

## 11. CLAUDE.md template (create at repo root)

Drop this verbatim into `CLAUDE.md` in the repo root, with placeholders filled in. Claude Code will auto-load this on every session.

```markdown
# CLAUDE.md

Conventions for the SafeZone DaVinci Resolve plugin. Read before every session.

## Stack

- Lua 5.1-compatible (Resolve's embedded runtime)
- Fusion UI Manager (`fu.UIManager`, `bmd.UIDispatcher`)
- No external Lua runtime dependencies
- `busted` for unit tests (dev-only)
- Target OS: macOS primary; Windows/Linux supported on paper only

## Commands

- Syntax check: `./check.sh` (runs `luac -p` over all .lua)
- Unit tests: `busted spec/`
- Install (dev): `./install.sh` — symlinks `SafeZone/` into Resolve's Scripts/Utility/

## Architecture rules

- All state lives on the timeline (overlay clips named `__SZ_*`). Never write external config, project metadata, or hidden files.
- Lazy-init Resolve handles inside functions. Never call `Resolve()` at module top level.
- Pure-logic modules (`presets.lua`, `detect.lua`) have no Resolve dependency and are unit-tested.
- Resolve-touching modules are not mocked — manual integration testing only.

## Code style

- 4-space indent (Lua convention varies; stick with 4 for consistency)
- `local` everything by default; explicit table-namespaced exports
- One module per file, returned as a table from the bottom: `return M`
- Function names: `snake_case`
- Module names match filename: `lib/overlay.lua` returns `overlay`
- No globals beyond Resolve's auto-injected (`Resolve`, `fu`, `bmd`, `app`)

## Workflow

- Initial commit: direct to main (per Stephan's workflow exception for new repos)
- All subsequent changes: feature branch → PR → review → merge
- No force push, no history rewriting
- One commit per phase from `SAFEZONE_PLAN.md` §6

## Design preferences (for any GUI/visual choices)

- Accent palette: cyan, violet, scarlet, magenta/pink, pastels
- Sharp corners (technical feel, not friendly)
- Dark UI default
- Mix sans UI with editorial italic serif display where applicable
- Borders on controls, shadows on cards
- Avoid: grey minimalism, corporate blue, filler copy, cramped margins, color mismatches

## API verification

Before using any DaVinci Resolve scripting API call not already used in this codebase, verify against:
`~/Library/Application Support/Blackmagic Design/DaVinci Resolve/Developer/Scripting/README.txt`

Field names and method signatures vary across Resolve versions. The plan doc's API examples may be stale.

## Docs

- Spec (canonical): `SAFEZONE_PLAN.md`
- Build instructions: `CLAUDE_CODE_INSTRUCTIONS.md`
- User docs: `README.md`
- Test checklist: `TESTING.md`
- This file: conventions only — do not duplicate spec or build instructions here
```

---

## 12. Anti-patterns to avoid

- **Jumping to code without reading the plan.** Both the plan and `README.txt` come first. Every time.
- **Assuming API field names.** Verify in `README.txt`. The plan's API section is a starting point, not gospel.
- **Optimistic error handling.** Every Resolve API call returns something falsy on failure. Check it.
- **Closing over Resolve globals at module load.** `Resolve()` may not be available at require time. Always call inside a function.
- **Polling timers without cleanup.** Every `Start()` needs a `Stop()` in the close handler.
- **Silent fallbacks.** If a track is locked or an API returns nil, surface it in the GUI footer — don't silently no-op.
- **Adding "TODO" or "FIXME" comments.** Either fix it or surface it as a question to the user.
- **Touching files outside `SafeZone/`.** This is a self-contained plugin. No global config changes, no shell aliases, no Resolve preference edits.
- **Disabling overlay clips without telling the user.** The guard dialog is the only path. No silent disables (except as explicit auto-disable choice from the dialog).
- **Bundling unused PNGs.** Every PNG in `assets/` must be referenced by a preset.

---

## 13. References

- Spec: `SAFEZONE_PLAN.md` (sibling to this file)
- Resolve scripting API: `~/Library/Application Support/Blackmagic Design/DaVinci Resolve/Developer/Scripting/README.txt`
- Prompting framework basis: https://dev.to/_vjk/i-made-claude-code-think-before-it-codes-heres-the-prompt-bf
