# SafeZone

A DaVinci Resolve plugin that adds toggle-able social-media safe-zone and aspect-ratio overlays to the viewer via PNG clips on the timeline.

Overlays appear on a dedicated **SafeZone** video track, are colour-flagged Pink, and can be toggled on/off without removing them from the timeline. A pre-render guard detects when you navigate to the Deliver page with an overlay active and offers to disable it before you render.

---

## Requirements

- DaVinci Resolve 18 or later (tested on 21.0.0)
- macOS (Windows and Linux paths documented below but untested)

---

## Installation

### macOS

```bash
# Clone or download this repo, then from the repo root:
./install.sh
```

`install.sh` creates a symlink from Resolve's Utility scripts folder to the `SafeZone/` directory inside this repo, so any future updates take effect immediately (Resolve restart still required).

Manual install (copy instead of symlink):

```bash
cp -r SafeZone \
  ~/Library/Application\ Support/Blackmagic\ Design/DaVinci\ Resolve/Fusion/Scripts/Utility/
```

### Windows

```
Copy the SafeZone\ folder to:
%APPDATA%\Blackmagic Design\DaVinci Resolve\Support\Fusion\Scripts\Utility\
```

### Linux

```bash
cp -r SafeZone \
  ~/.local/share/DaVinciResolve/Fusion/Scripts/Utility/
```

### After installing

**Restart DaVinci Resolve.** SafeZone will appear under:

> Workspace → Scripts → Utility → SafeZone

You should see three items: **SafeZone**, **SafeZone_Toggle**, and **SafeZone_Render**.

---

## Keyboard shortcuts (recommended)

1. Open **DaVinci Resolve → Keyboard Customization** (⌘⌥K on macOS)
2. Search for `SafeZone` in the right-hand search field
3. Assign shortcuts to the three actions:

| Action | Suggested shortcut | What it does |
|---|---|---|
| **SafeZone** | ⌘⇧S | Opens the floating GUI |
| **SafeZone_Toggle** | ⌘⇧H | Toggles all overlays on/off without opening GUI |
| **SafeZone_Render** | _(optional)_ | Disables overlays and opens Deliver — same as Safe Render button |

4. Click **Save**

---

## Daily use

1. Hit your open shortcut → the SafeZone window floats up
2. Glance at the **status label** — it shows the detected timeline ratio (e.g. `Detected: 9:16`) and highlights matching platform buttons with **◆**
3. Click a platform button (TikTok, IG Reels, etc.) → overlay PNG appears on the timeline on a dedicated **SafeZone** track
4. Frame your shot; toggle the overlay on/off with your toggle shortcut as needed
5. When ready to render, click **Safe Render** in the GUI (disables overlays, opens Deliver)

### Stack mode

Tick **Stack mode** (or hold it checked) before clicking a second platform button to keep both overlays visible simultaneously — useful for cross-posting validation.

Without stack mode, clicking a new platform button replaces the existing overlay.

### Ratio-only overlays

The **Aspect ratio only** row adds a pure crop-frame overlay (no platform UI chrome) — useful for checking composition without committing to a specific platform's safe zones.

---

## Safety — pre-render guard

SafeZone includes a guard that detects when you navigate to the Deliver page while an overlay is active and offers to disable it before you render.

**Important limitation: the guard timer only runs while the SafeZone GUI window is open.**

If you close the GUI and navigate to Deliver manually, no dialog will appear. The intended workflow is to keep the small floating window open during your editing session.

If you start a render via a native DaVinci Resolve keyboard shortcut while the GUI is closed, there is no protection — remove or disable overlays manually before rendering in that case. This is a fundamental API constraint: DaVinci Resolve's scripting interface does not expose render hooks.

### Guard dialog options

When the guard fires you will see two buttons:

- **Disable & Continue** — disables all SafeZone overlay clips and lets you proceed to render
- **Keep Overlay (will render)** — leaves overlays as-is; use only if you intentionally want the overlay baked into the output

Dismissing the dialog with **×** is treated as **Keep Overlay** — it does not change overlay state.

---

## Uninstalling

If installed via symlink:

```bash
rm ~/Library/Application\ Support/Blackmagic\ Design/DaVinci\ Resolve/Fusion/Scripts/Utility/SafeZone
```

If installed via copy, remove the `SafeZone` folder from the Utility directory.

Existing overlay clips on your timelines are **not** removed — they are ordinary PNG clips and will remain in your projects. You can delete them manually or leave them (they just won't be identifiable by the plugin after reinstall).

---

## Overlay assets

The `SafeZone/assets/` directory contains the PNG overlays. They must be present for the plugin to function. See `SAFEZONE_PLAN.md §9` for asset specifications and generation instructions.

---

## Troubleshooting

**SafeZone doesn't appear in Workspace → Scripts → Utility**
- Restart Resolve after installing
- Confirm the `SafeZone/` folder (containing `SafeZone.lua`) is directly inside the `Utility/` folder, not nested inside another subfolder

**Overlay doesn't appear after clicking a platform button**
- Check the Resolve console (Workspace → Console) for `[SafeZone]` error messages
- Confirm the `SafeZone/assets/` folder exists and contains the PNG files
- The overlay is applied on the topmost unlocked video track named "SafeZone" — check that no track lock is blocking it

**Toggle shortcut does nothing**
- The toggle script requires an open timeline and at least one `__SZ_*` clip on the timeline
- If no clips are present, toggle is a silent no-op

**Guard dialog didn't appear when navigating to Deliver**
- The guard only runs while the GUI window is open — keep the floating window open during your session

---

## Development

```bash
# Syntax check all .lua files
./check.sh

# Run unit tests (requires busted: luarocks install busted)
busted spec/

# Install via symlink for live development
./install.sh
```

See `CLAUDE_CODE_INSTRUCTIONS.md` for the full build workflow and `SAFEZONE_PLAN.md` for the complete specification.
