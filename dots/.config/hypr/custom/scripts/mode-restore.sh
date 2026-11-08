#!/usr/bin/env bash
# Restore the desktop profile that was active when the session ended.
# Run before Quickshell starts so the wallpaper and policies are already in
# place for the first frame.

set -euo pipefail

PROFILES_FILE="$HOME/.config/illogical-impulse/profiles.json"
PROFILES_HELPER="$HOME/.config/hypr/custom/scripts/profiles.py"

# On a brand-new installation there is no profile yet. Let Quickshell create
# its normal default configuration on first login instead of writing a
# partial config file from here.
if [[ ! -f "$PROFILES_FILE" ]]; then
    exit 0
fi

exec python3 "$PROFILES_HELPER" restore
