#!/usr/bin/env bash
# Build and install a user-local Spotifast with per-desktop-mode backgrounds.
#
# Upstream Spotifast themes only change colours and do not support an image
# behind the window. This script applies the small patch in this folder to an
# upstream source release and installs the result under ~/.local. It never
# needs root and does not touch Spotifast's settings, sign-in or caches.

set -euo pipefail

VERSION="${SPOTIFAST_VERSION:-0.17.1}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/illogical-impulse/spotifast-build"
SOURCE="$CACHE/spotifast-$VERSION"
DEST="${XDG_DATA_HOME:-$HOME/.local/share}/illogical-impulse/spotifast"
BIN_DIR="$HOME/.local/bin"
ICON_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor/scalable/apps"
APP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"

if ! command -v cargo >/dev/null 2>&1; then
    echo "Rust/cargo is required to build Spotifast." >&2
    exit 1
fi
if ! command -v patch >/dev/null 2>&1; then
    echo "The 'patch' command is required." >&2
    exit 1
fi

mkdir -p "$CACHE"
if [[ ! -d "$SOURCE" ]]; then
    echo "Downloading Spotifast $VERSION source..."
    curl -L --fail --silent --show-error \
        "https://github.com/crmne/spotifast/archive/refs/tags/v$VERSION.tar.gz" \
        -o "$CACHE/source.tar.gz"
    tar -xzf "$CACHE/source.tar.gz" -C "$CACHE"
fi

cd "$SOURCE"
if [[ ! -f src/background.rs ]]; then
    echo "Applying the per-mode background patch..."
    patch -p1 < "$HERE/background.patch"
fi

echo "Building Spotifast (this can take several minutes)..."
cargo build --release --locked

mkdir -p "$DEST" "$BIN_DIR" "$ICON_DIR" "$APP_DIR"
install -m 755 target/release/spotifast "$DEST/spotifast"
ln -sfn "$DEST/spotifast" "$BIN_DIR/spotifast"
install -m 644 packaging/icons/spotifast.svg "$ICON_DIR/spotifast.svg"
# Use the absolute path: a desktop session does not always have ~/.local/bin
# in PATH, which makes the menu entry silently do nothing.
cat > "$APP_DIR/spotifast.desktop" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=Spotifast
GenericName=Music Player
Comment=A native Spotify client
Exec=$DEST/spotifast %u
TryExec=$DEST/spotifast
Terminal=false
Categories=AudioVideo;Audio;Player;Music;
Keywords=spotify;music;player;streaming;spotifast;
Icon=spotifast
StartupNotify=true
StartupWMClass=spotifast
MimeType=x-scheme-handler/spotify;
EOF
chmod 644 "$APP_DIR/spotifast.desktop"
update-desktop-database "$APP_DIR" >/dev/null 2>&1 || true

echo
echo "Installed: $DEST/spotifast"
echo "Command:   $BIN_DIR/spotifast"
echo "Make sure $BIN_DIR is in PATH."
