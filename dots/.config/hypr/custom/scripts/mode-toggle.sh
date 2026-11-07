#!/usr/bin/env bash
# Toggle between the weeb and sober visual profiles.

set -euo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/illogical-impulse"
MODE_FILE="$STATE_DIR/mode"
SHELL_CONFIG="$HOME/.config/illogical-impulse/config.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$STATE_DIR"

current="weeb"
if [[ -f "$MODE_FILE" ]]; then
    current="$(<"$MODE_FILE")"
fi

case "$current" in
    weeb) next="sober" ;;
    *) next="weeb" ;;
esac

# Remember the wallpaper used by the profile we are leaving.
if [[ -f "$SHELL_CONFIG" ]]; then
    current_wallpaper="$(jq -r '.background.wallpaperPath // empty' "$SHELL_CONFIG")"
    if [[ -n "$current_wallpaper" ]]; then
        printf '%s\n' "$current_wallpaper" > "$STATE_DIR/wallpaper-$current"
    fi
fi

exec "$SCRIPT_DIR/mode-apply.sh" "$next"
