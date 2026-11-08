#!/usr/bin/env bash
# Apply a desktop profile by id. Kept as a compatibility wrapper for older
# keybinds/scripts that still call mode-apply.sh.

set -euo pipefail

PROFILES_HELPER="$HOME/.config/hypr/custom/scripts/profiles.py"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/illogical-impulse"
mode="${1:-}"

if [[ -z "$mode" ]]; then
    if [[ -f "$STATE_DIR/mode" ]]; then
        mode="$(<"$STATE_DIR/mode")"
    else
        mode="weeb"
    fi
fi

exec python3 "$PROFILES_HELPER" apply "$mode"
