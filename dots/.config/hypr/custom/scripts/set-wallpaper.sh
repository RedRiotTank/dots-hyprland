#!/usr/bin/env bash
# Apply an image as the wallpaper for the active desktop profile.
# The image is copied into that profile's wallpaper folder first.

set -euo pipefail

image="${1:-}"
if [[ -z "$image" || ! -f "$image" ]]; then
    echo "Usage: set-wallpaper.sh <image>" >&2
    exit 1
fi

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/illogical-impulse"
PROFILES_HELPER="$HOME/.config/hypr/custom/scripts/profiles.py"
SWITCHWALL="$HOME/.config/quickshell/ii/scripts/colors/switchwall.sh"

mkdir -p "$STATE_DIR"

result="$(python3 "$PROFILES_HELPER" set-wallpaper "$image")"
profile_id="$(printf '%s' "$result" | jq -r '.id // empty')"
new_path="$(printf '%s' "$result" | jq -r '.wallpaper // empty')"

if [[ -z "$profile_id" || -z "$new_path" || ! -f "$new_path" ]]; then
    echo "Could not place the wallpaper in the active profile folder" >&2
    exit 1
fi

printf '%s\n' "$profile_id" > "$STATE_DIR/mode"
printf '%s\n' "$new_path" > "$STATE_DIR/wallpaper-$profile_id"

if [[ -x "$SWITCHWALL" ]]; then
    "$SWITCHWALL" --image "$new_path" --mode dark
else
    echo "Wallpaper switch script not found: $SWITCHWALL" >&2
    exit 1
fi
