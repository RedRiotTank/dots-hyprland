#!/usr/bin/env bash
# Open waypaper using the wallpaper folder of the active desktop profile.

set -euo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/illogical-impulse"
MODE_FILE="$STATE_DIR/mode"
PROFILES_FILE="$HOME/.config/illogical-impulse/profiles.json"

mode="weeb"
if [[ -f "$MODE_FILE" ]]; then
    mode="$(<"$MODE_FILE")"
fi

folder=""
if [[ -f "$PROFILES_FILE" ]]; then
    folder="$(jq -r --arg id "$mode" '.profiles[$id].wallpaperFolder // empty' "$PROFILES_FILE")"
fi

if [[ -z "$folder" ]]; then
    folder="$HOME/Pictures/Wallpapers/$mode"
fi

mkdir -p "$folder"

if ! command -v waypaper >/dev/null 2>&1; then
    notify-send -a "Waypaper" -i "dialog-error" "Waypaper is not installed" >/dev/null 2>&1 || true
    exit 1
fi

exec waypaper --folder "$folder" --config-file "$HOME/.config/waypaper/config.ini"
