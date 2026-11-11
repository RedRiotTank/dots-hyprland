# Spotifast per-mode background patch

Upstream Spotifast's custom themes only change colours. This folder contains a small patch
that adds an image behind the main window, plus a user-local build/install script.

## Install

```bash
./sdata/spotifast-background/install.sh
```

The script downloads the pinned upstream source, applies `background.patch`, builds with cargo,
and installs:

- `~/.local/share/illogical-impulse/spotifast/spotifast`
- a `spotifast` symlink in `~/.local/bin`
- the Spotifast desktop entry and icon under `~/.local/share`

It never uses sudo and does not modify Spotifast's settings, sign-in, playlists or caches.

## How the desktop modes use it

`profiles.py` writes the active image path to:

```text
~/.config/spotifast/background-image
```

An open Spotifast checks that file about twice a second and reloads the image without
interrupting playback. The patch paints the image on the window's background layer, keeps
the central page transparent, and leaves sidebars, the player bar and menus readable with a
dark overlay and translucent fills.

Images are stored in `~/Pictures/spotifast/<profile-id>.<ext>` (or a `<profile-id>/`
folder). Choose or disable them from **Desktop modes** (`Super + Shift + W`).

## Notes

- The patch is pinned to Spotifast `0.17.1`. A newer upstream release may need a refreshed
  patch; set `SPOTIFAST_VERSION` to build another version after checking that it applies.
- If the patched binary misbehaves, the official build can be restored by reinstalling the
  `spotifast-bin` AUR package or the upstream release.
