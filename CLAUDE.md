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

NOTE: As of the initial build (Resolve 21.0.0, 2026-05-28), this file does not exist on the dev machine.
API assumptions are based on Resolve 17–21 training-data knowledge. Calls marked `-- VERIFY` have
been identified as uncertain and must be confirmed during manual integration testing.

Field names and method signatures vary across Resolve versions. The plan doc's API examples may be stale.

## Docs

- Spec (canonical): `SAFEZONE_PLAN.md`
- Build instructions: `CLAUDE_CODE_INSTRUCTIONS.md`
- User docs: `README.md`
- Test checklist: `TESTING.md`
- This file: conventions only — do not duplicate spec or build instructions here
