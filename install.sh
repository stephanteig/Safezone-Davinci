#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_SRC="$SCRIPT_DIR/SafeZone"

# DaVinci Resolve Utility scripts folder (macOS)
RESOLVE_UTILITY="$HOME/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts/Utility"

if [[ ! -d "$PLUGIN_SRC" ]]; then
    echo "ERROR: SafeZone/ directory not found at $PLUGIN_SRC" >&2
    exit 1
fi

if [[ ! -d "$RESOLVE_UTILITY" ]]; then
    echo "ERROR: Resolve Utility scripts folder not found:" >&2
    echo "  $RESOLVE_UTILITY" >&2
    echo "Make sure DaVinci Resolve is installed." >&2
    exit 1
fi

LINK_PATH="$RESOLVE_UTILITY/SafeZone"

if [[ -L "$LINK_PATH" ]]; then
    echo "Removing existing symlink: $LINK_PATH"
    rm "$LINK_PATH"
elif [[ -e "$LINK_PATH" ]]; then
    echo "ERROR: $LINK_PATH exists and is not a symlink." >&2
    echo "Remove it manually, then re-run install.sh." >&2
    exit 1
fi

ln -s "$PLUGIN_SRC" "$LINK_PATH"
echo "Installed: $LINK_PATH -> $PLUGIN_SRC"
echo ""
echo "Restart DaVinci Resolve, then find SafeZone under:"
echo "  Workspace → Scripts → Utility → SafeZone"
