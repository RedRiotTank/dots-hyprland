#!/usr/bin/env bash
# Open waypaper using the wallpaper folder of the active profile.

set -euo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/illogical-impulse"
MODE_FILE="$STATE_DIR/mode"

mode="weeb"
if [[ -f "$MODE_FILE" ]]; then
    mode="$(<"$MODE_FILE")"
fi

case "$mode" in
    weeb) folder="$HOME/Pictures/Wallpapers/weeb" ;;
    *) folder="$HOME/Pictures/Wallpapers/sober" ;;
esac

mkdir -p "$folder"

if ! command -v waypaper >/dev/null 2>&1; then
    notify-send -a "Waypaper" -i "dialog-error" "Waypaper is not installed" >/dev/null 2>&1 || true
    exit 1
fi

exec waypaper --folder "$folder" --config-file "$HOME/.config/waypaper/config.ini"
