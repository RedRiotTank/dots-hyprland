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
    DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
    folder="$DATA_HOME/redOpinion_IlogicalImpulse/$mode/wallpapers"
fi

mkdir -p "$folder"

if ! command -v waypaper >/dev/null 2>&1; then
    notify-send -a "Waypaper" -i "dialog-error" "Waypaper is not installed" >/dev/null 2>&1 || true
    exit 1
fi

CONFIG_FILE="$HOME/.config/waypaper/config.ini"
if [[ ! -f "$CONFIG_FILE" ]]; then
    # Generate a user-specific config instead of shipping one with absolute
    # paths. The profile helper rewrites these values when a mode is applied.
    mkdir -p "$(dirname "$CONFIG_FILE")"
    cat > "$CONFIG_FILE" <<EOF
[Settings]
language = en
backend = none
folder = $folder
wallpaper =
show_path_in_tooltip = True
fill = fill
sort = name
color = #ffffff
subfolders = False
all_subfolders = False
show_hidden = False
show_gifs_only = False
zen_mode = False
post_command = $HOME/.config/quickshell/ii/scripts/colors/switchwall.sh --image "\$wallpaper"
number_of_columns = 3
EOF
fi

exec waypaper --folder "$folder" --config-file "$CONFIG_FILE"
