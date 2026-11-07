#!/usr/bin/env bash
# Apply an image as the wallpaper for the current weeb/sober profile.

set -euo pipefail

image="${1:-}"
if [[ -z "$image" || ! -f "$image" ]]; then
    echo "Usage: set-wallpaper.sh <image>" >&2
    exit 1
fi

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/illogical-impulse"
MODE_FILE="$STATE_DIR/mode"
SWITCHWALL="$HOME/.config/quickshell/ii/scripts/colors/switchwall.sh"

mode="weeb"
if [[ -f "$MODE_FILE" ]]; then
    mode="$(<"$MODE_FILE")"
fi

mkdir -p "$STATE_DIR"
printf '%s\n' "$image" > "$STATE_DIR/wallpaper-$mode"

if [[ -x "$SWITCHWALL" ]]; then
    "$SWITCHWALL" --image "$image" --mode dark
else
    echo "Wallpaper switch script not found: $SWITCHWALL" >&2
    exit 1
fi
