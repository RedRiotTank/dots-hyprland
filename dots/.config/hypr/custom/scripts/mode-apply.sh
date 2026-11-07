#!/usr/bin/env bash
# Apply the visual profile (weeb or sober) across the desktop.
# Usage: mode-apply.sh [weeb|sober]

set -euo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/illogical-impulse"
MODE_FILE="$STATE_DIR/mode"
SHELL_CONFIG="$HOME/.config/illogical-impulse/config.json"
SWITCHWALL="$HOME/.config/quickshell/ii/scripts/colors/switchwall.sh"
WAYPAPER_CONFIG="$HOME/.config/waypaper/config.ini"

WEEB_DIR="$HOME/Pictures/Wallpapers/weeb"
SOBER_DIR="$HOME/Pictures/Wallpapers/sober"
WEEB_DEFAULT="$WEEB_DIR/Makima.jpg"
SOBER_DEFAULT="$SOBER_DIR/highlands-grid.jpg"

mkdir -p "$STATE_DIR" "$WEEB_DIR" "$SOBER_DIR"

mode="${1:-}"
if [[ "$mode" != "weeb" && "$mode" != "sober" ]]; then
    if [[ -f "$MODE_FILE" ]]; then
        mode="$(<"$MODE_FILE")"
    else
        mode="weeb"
    fi
fi

case "$mode" in
    weeb)
        folder="$WEEB_DIR"
        default_wallpaper="$WEEB_DEFAULT"
        weeb_value=1
        label="Weeb"
        ;;
    sober)
        folder="$SOBER_DIR"
        default_wallpaper="$SOBER_DEFAULT"
        weeb_value=0
        label="Sober"
        ;;
esac

wallpaper_file="$STATE_DIR/wallpaper-$mode"
if [[ -f "$wallpaper_file" && -s "$wallpaper_file" ]]; then
    wallpaper="$(<"$wallpaper_file")"
else
    wallpaper="$default_wallpaper"
fi

# Fall back to the original files if the per-mode copies are missing.
if [[ ! -f "$wallpaper" && "$mode" == "weeb" ]]; then
    wallpaper="$HOME/Pictures/Wallpapers/Makima.jpg"
elif [[ ! -f "$wallpaper" && "$mode" == "sober" ]]; then
    wallpaper="$HOME/Pictures/Wallpapers/highlands-grid.jpg"
fi

printf '%s\n' "$mode" > "$MODE_FILE"
printf '%s\n' "$wallpaper" > "$wallpaper_file"

# Update the shell policy and the wallpaper path before regenerating colors.
if [[ -f "$SHELL_CONFIG" ]]; then
    tmp="$(mktemp)"
    jq --argjson weeb "$weeb_value" --arg wallpaper "$wallpaper" \
        '.policies.weeb = $weeb | .background.wallpaperPath = $wallpaper' \
        "$SHELL_CONFIG" > "$tmp" && mv "$tmp" "$SHELL_CONFIG"

    # Seed the floating image list with the requested GIF on first use.
    miku_gif="$HOME/Pictures/Wallpapers/miku.gif"
    if [[ "$mode" == "weeb" && -f "$miku_gif" ]]; then
        sources_count="$(jq -r '(.overlay.floatingImage.sources // []) | length' "$SHELL_CONFIG")"
        if [[ "$sources_count" == "0" ]]; then
            tmp="$(mktemp)"
            jq --arg miku "$miku_gif" \
                '.overlay.floatingImage.sources = [$miku] | .overlay.floatingImage.imageSource = $miku' \
                "$SHELL_CONFIG" > "$tmp" && mv "$tmp" "$SHELL_CONFIG"
        fi
    fi
fi

# Keep waypaper pointed at the current mode folder. Its post-command routes
# selections back into illogical-impulse instead of fighting the shell layer.
mkdir -p "$(dirname "$WAYPAPER_CONFIG")"
if [[ ! -f "$WAYPAPER_CONFIG" ]]; then
    printf '[Settings]\n' > "$WAYPAPER_CONFIG"
fi
python3 - "$WAYPAPER_CONFIG" "$folder" "$wallpaper" "$SWITCHWALL" <<'PY'
import configparser
import sys

path, folder, wallpaper, switchwall = sys.argv[1:]
parser = configparser.ConfigParser()
parser.optionxform = str
parser.read(path)
if not parser.has_section("Settings"):
    parser.add_section("Settings")
section = parser["Settings"]
section["folder"] = folder
section["wallpaper"] = wallpaper
section["backend"] = "none"
section["post_command"] = f'{switchwall} --image "$wallpaper"'
with open(path, "w", encoding="utf-8") as handle:
    parser.write(handle, space_around_delimiters=True)
PY

# Apply the wallpaper and regenerate the Material colors for the new profile.
if [[ -x "$SWITCHWALL" && -f "$wallpaper" ]]; then
    "$SWITCHWALL" --image "$wallpaper" --mode dark >/dev/null 2>&1 || true
fi

# Floating images are hidden in sober mode by the shell itself. Their state is
# intentionally left untouched so they come back exactly as they were.

notify-send -a "Illogical Impulse" -i "preferences-desktop-theme" \
    "Mode: $label" "Wallpaper: $(basename "$wallpaper")" >/dev/null 2>&1 || true
