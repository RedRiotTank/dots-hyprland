<div align="center">

<img src=".github/assets/illogical-impulse.svg" alt="Illogical Impulse" width="520" />

# Illogical Impulse — Opinionated Edition

**A personal, opinionated fork of [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland) with configurable desktop profiles, a new Music tab, and multi-monitor overlay improvements.**

[![Upstream](https://img.shields.io/badge/upstream-end--4%2Fdots--hyprland-1f6feb?style=for-the-badge&logo=github)](https://github.com/end-4/dots-hyprland)
[![Fork](https://img.shields.io/badge/fork-RedRiotTank%2Fdots--hyprland-8957e5?style=for-the-badge&logo=github)](https://github.com/RedRiotTank/dots-hyprland)
[![License](https://img.shields.io/badge/license-GPL--3.0-2ea44f?style=for-the-badge)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Arch%20Linux-1793d1?style=for-the-badge&logo=archlinux)](https://archlinux.org)

</div>

> [!IMPORTANT]
> This is an **opinionated personal fork**, not an official release of illogical-impulse.
> It is built around the author's workflow and defaults. Upstream support channels may not
> be able to help with issues introduced here. If you want the canonical, unmodified
> experience, use [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland).

---

## Table of contents

- [What is this?](#what-is-this)
- [Highlights](#highlights)
- [Opinionated defaults](#opinionated-defaults)
- [Requirements](#requirements)
- [Installation](#installation)
- [Updating](#updating)
- [Uninstalling](#uninstalling)
- [Post-install checklist](#post-install-checklist)
- [Keybindings](#keybindings)
- [Optional integrations](#optional-integrations)
- [Troubleshooting](#troubleshooting)
- [Credits](#credits)
- [License](#license)

---

## What is this?

This repository is a fork of **illogical-impulse**, the Quickshell-based desktop shipped by
[**end-4/dots-hyprland**](https://github.com/end-4/dots-hyprland).

The upstream project provides the Hyprland configuration, the Quickshell shell, the material
color pipeline, installation scripts, and most of the widgets. This fork keeps that foundation
and adds a set of workflow-focused changes on top of it.

- Upstream repository: <https://github.com/end-4/dots-hyprland>
- Upstream documentation: <https://ii.clsty.link>
- Fork repository: <https://github.com/RedRiotTank/dots-hyprland>
- Upstream base at the time of this fork: `2f2a376`

This fork is not affiliated with, endorsed by, or supported by the upstream project.

It is intended for people who want:

- multiple configurable **desktop modes/profiles**;
- a **Music tab** with lyrics, playback, and recommendations;
- a **multi-monitor-aware overlay** for floating images;
- a small set of practical quality-of-life fixes.

The fork is distributed under the same GPL-3.0 license as upstream.

---

## Highlights

Everything in this section is an addition or extension compared with upstream
illogical-impulse.

### Extended desktop modes (profiles)

Upstream illogical-impulse offers a **weeb policy** switch. This fork extends that idea into a
full desktop-mode system:

- unlimited profiles, each with its own wallpaper folder;
- a selected wallpaper and optional wallpaper rotation interval;
- floating-image visibility;
- colored or flat sidebar icons;
- terminal greeting style (`pokemon-colorscripts` or CachyOS `fastfetch`);
- per-profile sidebar tab visibility.

Profiles are stored in:

```text
~/.config/illogical-impulse/profiles.json
```

The last active profile is restored automatically at login. A preview-based mode selector is
available with `Super + Shift + W`, and profiles can be created, edited, applied, or deleted
without leaving the shell.

### New Music tab

This fork adds a **Music** tab to the left sidebar. It combines the existing lyrics workflow
with a complete playback-focused view:

- album art with title and artist;
- synced lyrics that scroll vertically, Spotify-style, with the current line highlighted;
- elapsed time, remaining time, and a seekable progress bar;
- previous / play-pause / next controls;
- a cava visualizer flush with the bottom edge of the panel;
- recommended tracks based on the current artist.

Recommendations open on the platform that is currently playing:

| Active platform | Behavior |
| --- | --- |
| YouTube / YouTube Music | Resolves the first matching video and opens it directly. |
| Spotify | Opens the exact track search in Spotify. Direct playback is supported when API credentials are configured (see [Optional integrations](#optional-integrations)). |
| Unknown player | Falls back to a YouTube search. |

### New Reddit tab

- A dedicated **Reddit** sidebar tab with the Reddit logo and branding.
- Reddit feeds are fetched from the public Reddit JSON API first, with RSS and cache fallbacks.
- The tab participates in the same per-profile visibility and colored/flat icon settings as the
  rest of the sidebar.

### Anime improvements

- Booru images are requested using the larger sample/file URL instead of the tiny preview
  thumbnail, so cards and wallpapers keep their resolution.
- Image and monitor resolutions are compared before applying a booru image as the wallpaper.
  A confirmation dialog is shown for images that are too small.
- A **Set as Wallpaper** action was added to the booru context menu.
- The wallpaper is copied into the active desktop profile's folder and applied through the
  current profile helper.
- Images can be opened, downloaded, or selected as the wallpaper from the same menu.

### Multi-monitor overlay and floating images

The overlay is now aware of multiple monitors:

- pinned widgets remember their position, scale, and monitor;
- `Super + G` opens the overlay on the monitor under the cursor/focus;
- pinned floating images stay on their own monitor;
- each monitor can keep its own widget layout.

Floating images additionally gain:

- multiple independent image slots;
- a per-image file picker;
- multiple image sources instead of a single global image;
- persisted positions and scales across sessions.

### Sidebar and bar quality of life

- Tab visibility is configured from **Desktop modes**, removing the old in-sidebar editor.
- Added a per-profile **Colored icons** toggle with colored brand-style icons for AI,
  Translator, Anime, Reddit, and Music; the same icons can be rendered as flat theme glyphs.
- Clicking the resource meters in the top bar opens **btop** in the configured terminal.
- Resource indicators use a pointer cursor when hovered.
- The weather popup and city search open on the correct monitor and remember the selected city
  and coordinates.
- Weather fetching retries after login if the network is not ready yet.
- The built-in wallpaper selector and waypaper integration use the active profile's wallpaper
  folder.

### Wallpaper and artwork reliability

- Missing or deleted profile wallpapers are repaired automatically from the profile folder.
- A bundled default wallpaper is used on a fresh installation when a profile folder is empty.
- Album artwork is validated before use; incomplete downloads are re-downloaded automatically.
- Wallpaper rotation keeps track of the last displayed image across sessions.

---

## Opinionated defaults

This fork intentionally ships with the author's defaults. **Review them after installation.**

The most important ones are in:

```text
~/.config/hypr/custom/general.lua
~/.config/hypr/custom/rules.lua
~/.config/hypr/custom/keybinds.lua
~/.config/fish/conf.d/00-user.fish
```

Notable assumptions:

- Spanish keyboard layout (`kb_layout = "es"`).
- A multi-monitor layout using `DP-1` and `HDMI-A-2`.
- Workspace-to-monitor rules for that layout.
- `no_hardware_cursors = 1` to work around a dual-GPU cursor artifact.
- Personal application shortcuts (IntelliJ, Dolphin, etc.).
- Pokemon terminal greeting in the default **Weeb** profile.
- Weeb profile with colored icons enabled; Sober profile with flat icons.

If your monitors or keyboard differ, edit those files before logging in. On a fresh user,
the fork's `custom` configuration is installed automatically. If you already have a
`~/.config/hypr/custom` directory, the installer preserves it, so you must merge the fork's
files manually (see [Installation](#installation)).

---

## Requirements

### Tested environment

- Arch Linux or an Arch-based distribution.
- Hyprland with the Lua configuration loader expected by upstream.
- Quickshell (installed by the upstream setup script).
- Wayland session.

The setup script also supports other distributions through upstream's distro-specific
dependency scripts. This fork has been tested primarily on **CachyOS / Arch Linux**.

### Installed automatically by the setup script

Most dependencies are provided by the upstream metapackages. The fork additionally relies on:

- `python` — desktop profiles, lyrics helper, recommendation launcher.
- `curl` — weather, lyrics, recommendations, album art.
- `jq` — profile/state helpers.
- `coreutils` — image validation helpers.
- `imagemagick` — wallpaper processing.
- `cava` — music visualizer.
- `playerctl` — media control fallback.
- `kdialog` — file/folder pickers.
- `btop` — resource meter action in the bar.
- `xdg-utils` — opening recommendations in the active platform.
- `libnotify` — desktop notifications.

### Optional

- `waypaper` — optional wallpaper picker bound to `Super + Alt + W`.
- `pokemon-colorscripts-git` — optional Pokemon terminal greeting.
- A local Spotify client, and optionally Spotify API credentials, for the best
  recommendation experience.

---

## Installation

> [!WARNING]
> Do not run the installer as root. Use a regular user account.

### Fresh installation

```bash
git clone https://github.com/RedRiotTank/dots-hyprland.git
cd dots-hyprland
./setup install
```

If this fork keeps the custom edition in a separate branch, check it out before running the
installer:

```bash
git clone -b changes https://github.com/RedRiotTank/dots-hyprland.git
cd dots-hyprland
./setup install
```

The upstream installer will:

1. install dependencies;
2. configure permissions and services;
3. copy the config files into your home directory.

On a fresh user, `~/.config/hypr/custom` does not exist, so the fork-specific mode scripts,
keybindings, and defaults are installed automatically.

After installation, log out and start a **new Hyprland session**. The profile that was active
when the session ended is restored on the next login.

### Existing illogical-impulse users

The upstream installer intentionally preserves an existing `~/.config/hypr/custom` directory.
Because this fork stores its desktop-mode logic there, an existing custom directory means the
new features will not be installed automatically.

Back it up and let the fork install its own version:

```bash
mv ~/.config/hypr/custom ~/.config/hypr/custom.backup
./setup install
```

Then merge anything you still need from `~/.config/hypr/custom.backup` into the new
`~/.config/hypr/custom`, especially:

- monitor entries;
- keyboard layout;
- personal keybindings;
- any machine-specific rules.

If `~/.config/fish/conf.d/00-user.fish` already exists, merge the fork's version manually:

```bash
cp ~/.config/fish/conf.d/00-user.fish ~/.config/fish/conf.d/00-user.fish.backup
cp dots/.config/fish/conf.d/00-user.fish ~/.config/fish/conf.d/00-user.fish
```

### First-run notes

- Wallpaper fallback uses `~/.config/quickshell/ii/assets/images/default_wallpaper.png`
  if the profile folders are empty.
- Create personal wallpaper folders if you want your own images:
  ```bash
  mkdir -p ~/Pictures/Wallpapers/weeb ~/Pictures/Wallpapers/sober
  ```
- Open **Desktop modes** with `Super + Shift + W` to create or edit profiles.
- If `waypaper` is not installed, the `Super + Alt + W` shortcut displays a notification
  instead of opening a picker. The built-in wallpaper selector still works.

---

## Updating

Pull the latest fork changes and re-run the installer:

```bash
cd dots-hyprland
git pull
./setup install
```

The upstream installer preserves existing user-owned custom files. If a new release adds a
file to `dots/.config/hypr/custom`, copy or merge it manually.

After updating, restart the shell:

```bash
pkill qs
qs -c ii
```

or simply log out and back in.

---

## Uninstalling

```bash
cd dots-hyprland
./setup uninstall
```

See the upstream uninstall documentation for details about files and services that are kept.

---

## Post-install checklist

1. Edit `~/.config/hypr/custom/general.lua`:
   - set your keyboard layout;
   - replace `DP-1` / `HDMI-A-2` with your outputs;
   - adjust or remove the `no_hardware_cursors` workaround if it is not needed.
2. Edit `~/.config/hypr/custom/rules.lua` if your workspace-to-monitor layout differs.
3. Review `~/.config/hypr/custom/keybinds.lua` and remove shortcuts for applications you
   do not use.
4. Open `Super + Shift + W` and create/edit your desktop modes.
5. Add wallpapers to the profile folders, or pick one from the built-in selector.
6. Optional: install `waypaper` and `pokemon-colorscripts-git` for the corresponding extras.
7. Optional: configure Spotify API credentials if you want direct Spotify playback from
   recommendations.

---

## Keybindings

These are the fork-specific shortcuts added on top of upstream defaults:

| Shortcut | Action |
| --- | --- |
| `Super + Shift + W` | Open the Desktop modes selector. |
| `Super + Alt + W` | Open waypaper using the active profile's wallpaper folder. |
| `Super + G` | Toggle the overlay on the focused monitor. |
| `Super + A` | Toggle the left sidebar (AI, Translator, Anime, Reddit, Music). |
| `Ctrl + Super + T` | Open the wallpaper selector. |
| `Super + F1` / `Super + H` | Open the keybind cheatsheet. |

Some upstream shortcuts differ because `custom/keybinds.lua` intentionally unbinds and
remaps a few defaults.

---

## Optional integrations

### Direct Spotify recommendation playback

Spotify does not provide anonymous track search or playback without app credentials. To let
recommendations launch the actual track in the Spotify desktop client, export:

```bash
export SPOTIFY_CLIENT_ID="your_client_id"
export SPOTIFY_CLIENT_SECRET="your_client_secret"
```

Put them in your session environment, for example in `~/.config/uwsm/env`, then restart the
session. Create a Spotify application at <https://developer.spotify.com/dashboard> if needed.

Without credentials, clicking a recommendation in Spotify opens the exact search in Spotify.
YouTube and YouTube Music recommendations open directly in the browser.

### Waypaper

`Super + Alt + W` uses `waypaper` to browse the active profile's folder. This is optional;
desktop modes and the built-in wallpaper selector work without it.

### Pokemon terminal greeting

The default Weeb profile can use `pokemon-colorscripts`. If it is missing, the fish greeting
falls back to the normal CachyOS `fastfetch` output.

### btop

Clicking the resource meters in the top bar launches `btop` in the configured terminal.

---

## Troubleshooting

### Desktop modes are missing after installing over an existing setup

The installer preserved your old `~/.config/hypr/custom`. See
[Existing illogical-impulse users](#existing-illogical-impulse-users) and merge the fork's
custom files.

### Wallpaper is empty after a fresh install

Check the active profile in `~/.config/illogical-impulse/profiles.json`. If its folder has no
images, the fork falls back to the bundled default wallpaper. Add images and apply the mode
again with `Super + Shift + W`.

### Music album art is not updating

The fork validates downloaded artwork and re-downloads incomplete files automatically. If the
problem persists, check network access to `i.scdn.co` (Spotify) or remove the corresponding
file from:

```text
~/.cache/quickshell/media/coverart/
```

### Recommendations do not open the right application

Check the currently active MPRIS player:

```bash
playerctl -l
playerctl metadata --format '{{playerName}} {{title}}'
```

Spotify direct playback requires the credentials described above. YouTube and YouTube Music
open directly.

### I want the upstream experience

Use [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland). This fork is not a
replacement for upstream support.

---

## Credits

Huge thanks to the upstream project and everyone who contributes to it:

- [**end-4/dots-hyprland**](https://github.com/end-4/dots-hyprland) — the original
  illogical-impulse dotfiles and installation system.
- [Hyprland](https://github.com/hyprwm/hyprland) — the Wayland compositor.
- [Quickshell](https://quickshell.outfoxxed.me/) — the widget system.
- Upstream maintainers and contributors, especially those credited in the original README.
- All upstream testers, translators, and package maintainers.

This fork would not exist without their work.

---

## License

GPL-3.0. See [LICENSE](LICENSE).

The upstream project and third-party assets retain their respective licenses. If you
redistribute this fork, keep the upstream attribution and license notices intact.

---

<div align="center">

**Not affiliated with the upstream project.**  
Use at your own risk, and enjoy your desktop.

</div>
