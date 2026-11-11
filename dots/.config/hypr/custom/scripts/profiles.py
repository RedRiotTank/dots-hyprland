#!/usr/bin/env python3
"""Manage illogical-impulse desktop profiles.

Profiles are stored in ~/.config/illogical-impulse/profiles.json. Each profile
has its own wallpaper folder, wallpaper, terminal style, floating-image
setting, weeb policy and sidebar tab visibility.
"""

from __future__ import annotations

import base64
import configparser
import filecmp
import json
import mimetypes
import os
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.parse
from pathlib import Path

HOME = Path.home()
CONFIG_DIR = HOME / ".config" / "illogical-impulse"
PROFILES_FILE = CONFIG_DIR / "profiles.json"
SHELL_CONFIG = CONFIG_DIR / "config.json"
STATE_DIR = Path(os.environ.get("XDG_STATE_HOME", HOME / ".local" / "state")) / "illogical-impulse"
STATES_FILE = Path(os.environ.get("XDG_STATE_HOME", HOME / ".local" / "state")) / "quickshell" / "states.json"
WAYPAPER_CONFIG = HOME / ".config" / "waypaper" / "config.ini"
SWITCHWALL = HOME / ".config" / "quickshell" / "ii" / "scripts" / "colors" / "switchwall.sh"
DEFAULT_WALLPAPER_DIR = HOME / "Pictures" / "Wallpapers"
FALLBACK_WALLPAPER = HOME / ".config" / "quickshell" / "ii" / "assets" / "images" / "default_wallpaper.png"
VESKTOP_DIR = HOME / "Pictures" / "vesktop"
VESKTOP_APP_DIR = HOME / ".config" / "vesktop"
VESKTOP_SETTINGS_DIR = VESKTOP_APP_DIR / "settings"
VESKTOP_QUICK_CSS = VESKTOP_SETTINGS_DIR / "quickCss.css"
VESKTOP_SETTINGS_FILE = VESKTOP_SETTINGS_DIR / "settings.json"
VESKTOP_THEMES_DIR = VESKTOP_APP_DIR / "themes"
VESKTOP_THEME_LINK = VESKTOP_THEMES_DIR / "ii-vesktop-backgrounds"
VESKTOP_BLOCK_START = "/* >>> illogical-impulse vesktop background >>> */"
VESKTOP_BLOCK_END = "/* <<< illogical-impulse vesktop background <<< */"

TAB_KEYS = ("ai", "translator", "anime", "social", "lyrics")
DEFAULT_TABS = {key: True for key in TAB_KEYS}
IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".avif", ".bmp", ".gif"}


def load_json(path: Path, fallback):
    try:
        with open(path, "r", encoding="utf-8") as handle:
            return json.load(handle)
    except Exception:
        return fallback


def save_json(path: Path, data) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=path.parent, delete=False) as handle:
        json.dump(data, handle, ensure_ascii=False, indent=2)
        temporary = handle.name
    os.replace(temporary, path)


def image_files(folder: Path) -> list[Path]:
    """Return the image wallpapers contained in a profile folder, sorted."""
    try:
        return sorted(
            entry for entry in folder.iterdir()
            if entry.is_file() and entry.suffix.lower() in IMAGE_EXTENSIONS
        )
    except OSError:
        return []


def same_file_content(left: Path, right: Path) -> bool:
    """Return True when both paths contain the same data."""
    try:
        if left.stat().st_size != right.stat().st_size:
            return False
        return filecmp.cmp(left, right, shallow=False)
    except OSError:
        return False


def resolve_wallpaper(folder: str, wallpaper: str) -> str:
    """Keep the configured wallpaper if it still exists, otherwise fall back
    to the first image in the profile folder. This prevents a deleted image
    (or a stale profile entry) from leaving the desktop without a wallpaper."""
    if wallpaper:
        candidate = Path(wallpaper).expanduser()
        if candidate.is_file():
            return str(candidate)
    files = image_files(Path(folder).expanduser())
    if files:
        return str(files[0])
    if FALLBACK_WALLPAPER.is_file():
        return str(FALLBACK_WALLPAPER)
    return ""


def resolve_vesktop_background(profile_id: str, current: str) -> str:
    """Return the image for a profile inside ~/Pictures/vesktop.

    A profile may use either a flat file (<profile-id>.<ext>) or a folder
    (<profile-id>/<image>). Paths outside that folder are ignored so the
    repository and profiles.json never depend on arbitrary locations.
    """
    if current:
        candidate = Path(current).expanduser()
        try:
            resolved = candidate.resolve()
            if resolved.is_file() and VESKTOP_DIR.resolve() in resolved.parents:
                return str(resolved)
        except OSError:
            pass

    try:
        for entry in sorted(VESKTOP_DIR.iterdir()):
            if entry.is_file() and entry.stem == profile_id and entry.suffix.lower() in IMAGE_EXTENSIONS:
                return str(entry)
    except OSError:
        pass

    files = image_files(VESKTOP_DIR / profile_id)
    return str(files[0]) if files else ""


def ensure_vesktop_theme_link() -> bool:
    """Expose ~/Pictures/vesktop to Vencord's vencord:// theme protocol."""
    try:
        VESKTOP_THEMES_DIR.mkdir(parents=True, exist_ok=True)
        target = VESKTOP_DIR.resolve()
        if VESKTOP_THEME_LINK.is_symlink():
            if VESKTOP_THEME_LINK.resolve() == target:
                return True
            VESKTOP_THEME_LINK.unlink()
        elif VESKTOP_THEME_LINK.exists():
            return False
        VESKTOP_THEME_LINK.symlink_to(target, target_is_directory=True)
        return True
    except OSError:
        return False


def vesktop_image_url(image: str) -> str:
    """Build a URL that Vencord can load from its theme protocol.

    Electron blocks plain file:// images from the Discord origin. Vencord
    serves files under ~/.config/vesktop/themes through vencord://, so the
    Pictures folder is exposed with a symlink. Data URLs are a fallback for
    filesystems where symlinks are unavailable.
    """
    path = Path(image)
    try:
        relative = path.resolve().relative_to(VESKTOP_DIR.resolve()).as_posix()
    except (OSError, ValueError):
        relative = path.name

    if ensure_vesktop_theme_link():
        return "vencord:///themes/ii-vesktop-backgrounds/" + urllib.parse.quote(relative)

    mime = mimetypes.guess_type(path.name)[0] or "image/png"
    encoded = base64.b64encode(path.read_bytes()).decode("ascii")
    return f"data:{mime};base64,{encoded}"


def strip_vesktop_block(content: str) -> str:
    pattern = re.compile(
        re.escape(VESKTOP_BLOCK_START) + r".*?" + re.escape(VESKTOP_BLOCK_END) + r"\n?",
        re.DOTALL,
    )
    return pattern.sub("", content)


def ensure_vesktop_quickcss_enabled() -> None:
    """Vencord must have QuickCSS enabled for the managed block to load."""
    if not VESKTOP_SETTINGS_FILE.is_file():
        return
    try:
        data = json.loads(VESKTOP_SETTINGS_FILE.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return
    if not isinstance(data, dict) or data.get("useQuickCss") is True:
        return
    data["useQuickCss"] = True
    save_json(VESKTOP_SETTINGS_FILE, data)


def update_vesktop(profile: dict) -> None:
    """Write or remove the managed QuickCSS block for a profile.

    Only the block between the markers is touched, so user CSS and themes are
    preserved. Vencord watches quickCss.css and applies the change live.
    """
    if not VESKTOP_APP_DIR.is_dir():
        return

    image = ""
    if profile.get("vesktopBackgroundEnabled", True):
        image = resolve_vesktop_background(profile.get("id", ""), profile.get("vesktopBackground") or "")
    if not image and not VESKTOP_QUICK_CSS.exists():
        return

    content = ""
    if VESKTOP_QUICK_CSS.is_file():
        try:
            content = VESKTOP_QUICK_CSS.read_text(encoding="utf-8")
        except OSError:
            content = ""
    content = strip_vesktop_block(content)

    if image:
        url = vesktop_image_url(image)
        block = "\n".join([
            VESKTOP_BLOCK_START,
            "/* Managed by illogical-impulse desktop modes. Do not edit inside the markers. */",
            ":root {",
            f'    --ii-vesktop-background: url("{url}");',
            "}",
            "#app-mount {",
            "    background:",
            "        linear-gradient(rgba(15, 16, 20, 0.45), rgba(15, 16, 20, 0.45)),",
            "        var(--ii-vesktop-background) center / cover no-repeat fixed !important;",
            "}",
            "#app-mount * {",
            "    background-color: transparent !important;",
            "}",
            '#app-mount [role="menu"],',
            '#app-mount [role="dialog"],',
            '#app-mount [role="listbox"] {',
            "    background-color: rgba(20, 21, 24, 0.92) !important;",
            "}",
            VESKTOP_BLOCK_END,
        ])
        content = content.rstrip() + ("\n\n" if content.strip() else "") + block + "\n"
    else:
        content = content.rstrip() + ("\n" if content.strip() else "")

    ensure_vesktop_quickcss_enabled()
    try:
        VESKTOP_SETTINGS_DIR.mkdir(parents=True, exist_ok=True)
        VESKTOP_QUICK_CSS.write_text(content, encoding="utf-8")
    except OSError:
        pass


def slugify(name: str) -> str:
    value = re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")
    return value or "mode"


def unique_id(base: str, profiles: dict) -> str:
    candidate = base
    index = 2
    while candidate in profiles:
        candidate = f"{base}-{index}"
        index += 1
    return candidate


def normalize_tabs(tabs) -> dict:
    result = dict(DEFAULT_TABS)
    if isinstance(tabs, dict):
        for key in TAB_KEYS:
            if key in tabs:
                result[key] = bool(tabs[key])
    return result


def normalize_profile(profile_id: str, profile: dict) -> dict:
    folder = profile.get("wallpaperFolder") or str(DEFAULT_WALLPAPER_DIR / profile_id)
    wallpaper = resolve_wallpaper(folder, profile.get("wallpaper") or "")
    try:
        wallpaper_interval = max(0, int(profile.get("wallpaperInterval", 0) or 0))
    except (TypeError, ValueError):
        wallpaper_interval = 0
    vesktop_enabled = bool(profile.get("vesktopBackgroundEnabled", True))
    return {
        "id": profile_id,
        "name": profile.get("name") or profile_id,
        "wallpaperFolder": folder,
        "wallpaper": wallpaper,
        "preview": wallpaper,
        "wallpaperInterval": wallpaper_interval,
        "floatingImages": bool(profile.get("floatingImages", False)),
        "weebPolicy": bool(profile.get("weebPolicy", False)),
        "coloredIcons": bool(profile.get("coloredIcons", profile_id != "sober")),
        "terminal": profile.get("terminal", "cachyos"),
        "vesktopBackgroundEnabled": vesktop_enabled,
        "vesktopBackground": resolve_vesktop_background(
            profile_id, profile.get("vesktopBackground") or ""
        ) if vesktop_enabled else "",
        "tabs": normalize_tabs(profile.get("tabs")),
    }


def current_state_tabs() -> dict:
    states = load_json(STATES_FILE, {})
    return normalize_tabs(states.get("sidebar", {}).get("leftPanel", {}))


def default_profiles() -> dict:
    mode_file = STATE_DIR / "mode"
    active = mode_file.read_text().strip() if mode_file.exists() else "weeb"
    config = load_json(SHELL_CONFIG, {})
    current_wallpaper = config.get("background", {}).get("wallpaperPath", "")
    current_floating = config.get("policies", {}).get("floatingImages", True)
    tabs = current_state_tabs()

    weeb_folder = DEFAULT_WALLPAPER_DIR / "weeb"
    sober_folder = DEFAULT_WALLPAPER_DIR / "sober"
    weeb_wallpaper = resolve_wallpaper(str(weeb_folder), "") or current_wallpaper
    sober_wallpaper = resolve_wallpaper(str(sober_folder), "") or current_wallpaper

    profiles = {
        "weeb": normalize_profile("weeb", {
            "name": "Weeb",
            "wallpaperFolder": str(weeb_folder),
            "wallpaper": weeb_wallpaper,
            "wallpaperInterval": 0,
            "floatingImages": bool(current_floating),
            "weebPolicy": True,
            "coloredIcons": True,
            "terminal": "pokemon",
            "tabs": tabs,
        }),
        "sober": normalize_profile("sober", {
            "name": "Sober",
            "wallpaperFolder": str(sober_folder),
            "wallpaper": sober_wallpaper,
            "wallpaperInterval": 0,
            "floatingImages": False,
            "weebPolicy": False,
            "coloredIcons": False,
            "terminal": "cachyos",
            "tabs": tabs,
        }),
    }
    if active not in profiles:
        active = "weeb"
    return {"active": active, "profiles": profiles}


def load_profiles() -> dict:
    if not PROFILES_FILE.exists():
        data = default_profiles()
        save_json(PROFILES_FILE, data)
        return data
    data = load_json(PROFILES_FILE, {})
    profiles = data.get("profiles", {})
    normalized = {}
    for profile_id, profile in profiles.items():
        if isinstance(profile, dict):
            normalized[profile_id] = normalize_profile(profile_id, profile)
    if not normalized:
        return default_profiles()
    active = data.get("active", next(iter(normalized)))
    if active not in normalized:
        active = next(iter(normalized))
    result = {"active": active, "profiles": normalized}
    # Persist self-healing changes such as a wallpaper that no longer exists.
    if result != data:
        save_json(PROFILES_FILE, result)
    return result


def list_payload(data: dict) -> dict:
    return {
        "active": data["active"],
        "profiles": [data["profiles"][profile_id] for profile_id in sorted(data["profiles"])],
    }


def update_config(profile: dict) -> None:
    config = load_json(SHELL_CONFIG, {})
    policies = config.setdefault("policies", {})
    policies["weeb"] = 1 if profile.get("weebPolicy") else 0
    policies["floatingImages"] = bool(profile.get("floatingImages", False))
    wallpaper = profile.get("wallpaper", "")
    if wallpaper:
        background = config.setdefault("background", {})
        background["wallpaperPath"] = wallpaper
        background["thumbnailPath"] = wallpaper
    save_json(SHELL_CONFIG, config)


def update_waypaper(profile: dict) -> None:
    WAYPAPER_CONFIG.parent.mkdir(parents=True, exist_ok=True)
    parser = configparser.ConfigParser()
    parser.optionxform = str
    parser.read(WAYPAPER_CONFIG)
    if not parser.has_section("Settings"):
        parser.add_section("Settings")
    section = parser["Settings"]
    section["folder"] = profile.get("wallpaperFolder", "")
    section["wallpaper"] = profile.get("wallpaper", "")
    section["backend"] = "none"
    section["post_command"] = f'{SWITCHWALL} --image "$wallpaper"'
    with open(WAYPAPER_CONFIG, "w", encoding="utf-8") as handle:
        parser.write(handle, space_around_delimiters=True)


def write_runtime_state(profile: dict) -> None:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    (STATE_DIR / "mode").write_text(profile["id"] + "\n", encoding="utf-8")
    (STATE_DIR / "terminal").write_text(profile.get("terminal", "cachyos") + "\n", encoding="utf-8")
    if profile.get("wallpaper"):
        (STATE_DIR / f"wallpaper-{profile['id']}").write_text(profile["wallpaper"] + "\n", encoding="utf-8")


def apply_profile(data: dict, profile_id: str, run_switchwall: bool = True) -> dict:
    if profile_id not in data["profiles"]:
        raise ValueError(f"Unknown profile: {profile_id}")
    data["active"] = profile_id
    profile = data["profiles"][profile_id]
    save_json(PROFILES_FILE, data)
    update_config(profile)
    update_waypaper(profile)
    write_runtime_state(profile)
    update_vesktop(profile)
    wallpaper = profile.get("wallpaper", "")
    if run_switchwall and wallpaper and Path(wallpaper).is_file() and SWITCHWALL.is_file():
        subprocess.run(
            [str(SWITCHWALL), "--image", wallpaper, "--mode", "dark"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )
    return profile


def create_profile(data: dict, name: str) -> dict:
    active = data["profiles"].get(data["active"], {})
    profile_id = unique_id(slugify(name or "new-mode"), data["profiles"])
    folder = DEFAULT_WALLPAPER_DIR / profile_id
    folder.mkdir(parents=True, exist_ok=True)

    wallpaper = ""
    source_wallpaper = active.get("wallpaper", "")
    if source_wallpaper and Path(source_wallpaper).is_file():
        suffix = Path(source_wallpaper).suffix or ".jpg"
        target = folder / f"wallpaper{suffix}"
        try:
            shutil.copy2(source_wallpaper, target)
            wallpaper = str(target)
        except OSError:
            wallpaper = ""

    profile = normalize_profile(profile_id, {
        "name": name or "New mode",
        "wallpaperFolder": str(folder),
        "wallpaper": wallpaper,
        "wallpaperInterval": 0,
        "floatingImages": bool(active.get("floatingImages", False)),
        "weebPolicy": bool(active.get("weebPolicy", False)),
        "coloredIcons": bool(active.get("coloredIcons", True)),
        "terminal": active.get("terminal", "cachyos"),
        "tabs": active.get("tabs", DEFAULT_TABS),
    })
    data["profiles"][profile_id] = profile
    save_json(PROFILES_FILE, data)
    return profile


def update_profile(data: dict, profile_id: str, patch: dict) -> dict:
    if profile_id not in data["profiles"]:
        raise ValueError(f"Unknown profile: {profile_id}")
    profile = data["profiles"][profile_id]
    for key in ("name", "wallpaperFolder", "wallpaper", "terminal"):
        if key in patch and isinstance(patch[key], str):
            profile[key] = patch[key]
    for key in ("floatingImages", "weebPolicy", "coloredIcons"):
        if key in patch:
            profile[key] = bool(patch[key])
    if "wallpaperInterval" in patch:
        try:
            profile["wallpaperInterval"] = max(0, int(patch["wallpaperInterval"]))
        except (TypeError, ValueError):
            profile["wallpaperInterval"] = 0
    if "tabs" in patch:
        profile["tabs"] = normalize_tabs({**profile.get("tabs", {}), **patch["tabs"]})
    # Repair a deleted/renamed wallpaper as soon as the profile is edited.
    profile["wallpaper"] = resolve_wallpaper(
        profile.get("wallpaperFolder", ""), profile.get("wallpaper", "")
    )
    profile["preview"] = profile.get("wallpaper", "")
    if profile.get("vesktopBackgroundEnabled", True):
        profile["vesktopBackground"] = resolve_vesktop_background(
            profile_id, profile.get("vesktopBackground") or ""
        )
    else:
        profile["vesktopBackground"] = ""
    data["profiles"][profile_id] = profile
    save_json(PROFILES_FILE, data)
    if data.get("active") == profile_id:
        update_vesktop(profile)
    return profile


def delete_profile(data: dict, profile_id: str) -> dict:
    if profile_id not in data["profiles"]:
        raise ValueError(f"Unknown profile: {profile_id}")
    if len(data["profiles"]) <= 1:
        raise ValueError("At least one profile is required")
    del data["profiles"][profile_id]
    if data["active"] == profile_id:
        data["active"] = next(iter(data["profiles"]))
        profile = data["profiles"][data["active"]]
        update_config(profile)
        update_waypaper(profile)
        write_runtime_state(profile)
        update_vesktop(profile)
    save_json(PROFILES_FILE, data)
    return data["profiles"][data["active"]]


def set_wallpaper(data: dict, image_path: str) -> dict:
    profile = data["profiles"].get(data["active"])
    if not profile:
        raise ValueError("No active profile")
    source = Path(image_path).expanduser().resolve()
    if not source.is_file():
        raise ValueError(f"Wallpaper not found: {image_path}")

    folder = Path(profile.get("wallpaperFolder", str(DEFAULT_WALLPAPER_DIR / profile["id"]))).expanduser()
    folder.mkdir(parents=True, exist_ok=True)

    if source.parent.resolve() == folder.resolve():
        target = source
    else:
        target = folder / source.name
        index = 2
        # Reuse an identical file instead of creating a new copy every time
        # the same wallpaper is selected from another folder.
        while target.exists() and not same_file_content(source, target):
            target = folder / f"{source.stem}-{index}{source.suffix}"
            index += 1
        if not target.exists():
            shutil.copy2(source, target)

    profile["wallpaper"] = str(target)
    profile["preview"] = str(target)
    data["profiles"][data["active"]] = profile
    save_json(PROFILES_FILE, data)
    update_waypaper(profile)
    (STATE_DIR / f"wallpaper-{profile['id']}").write_text(str(target) + "\n", encoding="utf-8")
    return profile


def set_vesktop_background(data: dict, profile_id: str, image_path: str) -> dict:
    """Copy an image into ~/Pictures/vesktop and assign it to a profile."""
    if profile_id not in data["profiles"]:
        raise ValueError(f"Unknown profile: {profile_id}")
    source = Path(image_path).expanduser().resolve()
    if not source.is_file():
        raise ValueError(f"Image not found: {image_path}")
    if source.suffix.lower() not in IMAGE_EXTENSIONS:
        raise ValueError(f"Unsupported image format: {source.suffix}")

    VESKTOP_DIR.mkdir(parents=True, exist_ok=True)
    target = VESKTOP_DIR / f"{profile_id}{source.suffix.lower()}"
    if source != target and not (target.exists() and same_file_content(source, target)):
        shutil.copy2(source, target)

    # Keep one canonical image per profile and remove older copies with a
    # different extension. Files that do not match the profile id are untouched.
    for old in VESKTOP_DIR.glob(f"{profile_id}.*"):
        try:
            if old.is_file() and old != target and old.suffix.lower() in IMAGE_EXTENSIONS:
                old.unlink()
        except OSError:
            pass

    profile = data["profiles"][profile_id]
    profile["vesktopBackgroundEnabled"] = True
    profile["vesktopBackground"] = str(target)
    data["profiles"][profile_id] = profile
    save_json(PROFILES_FILE, data)
    if data.get("active") == profile_id:
        update_vesktop(profile)
    return profile


def clear_vesktop_background(data: dict, profile_id: str) -> dict:
    """Disable the Vesktop background for a profile without deleting its image."""
    if profile_id not in data["profiles"]:
        raise ValueError(f"Unknown profile: {profile_id}")
    profile = data["profiles"][profile_id]
    profile["vesktopBackgroundEnabled"] = False
    profile["vesktopBackground"] = ""
    data["profiles"][profile_id] = profile
    save_json(PROFILES_FILE, data)
    if data.get("active") == profile_id:
        update_vesktop(profile)
    return profile


def rotate_wallpaper(data: dict, profile_id: str | None = None) -> dict:
    """Switch the active profile to the next wallpaper in its folder.

    This intentionally only updates the wallpaper path and the state files,
    not the full color scheme, so periodic rotation stays lightweight."""
    profile = data["profiles"].get(profile_id or data["active"])
    if not profile:
        raise ValueError("No active profile")
    folder = Path(profile.get("wallpaperFolder", "")).expanduser()
    files = image_files(folder)
    if not files:
        return profile

    current = Path(profile.get("wallpaper", "")).expanduser()
    try:
        index = files.index(current)
    except ValueError:
        index = -1
    target = files[(index + 1) % len(files)]

    if str(target) != profile.get("wallpaper"):
        profile["wallpaper"] = str(target)
        profile["preview"] = str(target)
        data["profiles"][profile["id"]] = profile
        save_json(PROFILES_FILE, data)
        update_config(profile)
        update_waypaper(profile)
        write_runtime_state(profile)
    return profile


def main() -> None:
    command = sys.argv[1] if len(sys.argv) > 1 else "list"
    data = load_profiles()

    try:
        if command == "list":
            print(json.dumps(list_payload(data), ensure_ascii=False))
        elif command == "apply":
            profile = apply_profile(data, sys.argv[2])
            print(json.dumps(profile, ensure_ascii=False))
        elif command == "restore":
            # Used on session startup: restore the last active profile without
            # regenerating the whole color scheme.
            profile = apply_profile(data, data["active"], run_switchwall=False)
            print(json.dumps(profile, ensure_ascii=False))
        elif command == "create":
            profile = create_profile(data, sys.argv[2] if len(sys.argv) > 2 else "New mode")
            print(json.dumps(profile, ensure_ascii=False))
        elif command == "update":
            profile = update_profile(data, sys.argv[2], json.loads(sys.argv[3]))
            print(json.dumps(profile, ensure_ascii=False))
        elif command == "delete":
            profile = delete_profile(data, sys.argv[2])
            print(json.dumps(profile, ensure_ascii=False))
        elif command == "set-wallpaper":
            profile = set_wallpaper(data, sys.argv[2])
            print(json.dumps(profile, ensure_ascii=False))
        elif command == "set-vesktop-background":
            profile = set_vesktop_background(data, sys.argv[2], sys.argv[3])
            print(json.dumps(profile, ensure_ascii=False))
        elif command == "clear-vesktop-background":
            profile = clear_vesktop_background(data, sys.argv[2])
            print(json.dumps(profile, ensure_ascii=False))
        elif command == "rotate-wallpaper":
            profile = rotate_wallpaper(data, sys.argv[2] if len(sys.argv) > 2 else None)
            print(json.dumps(profile, ensure_ascii=False))
        else:
            raise ValueError(f"Unknown command: {command}")
    except Exception as error:
        print(json.dumps({"error": str(error)}, ensure_ascii=False))
        sys.exit(1)


if __name__ == "__main__":
    main()
