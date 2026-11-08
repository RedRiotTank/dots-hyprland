#!/usr/bin/env python3
"""Manage illogical-impulse desktop profiles.

Profiles are stored in ~/.config/illogical-impulse/profiles.json. Each profile
has its own wallpaper folder, wallpaper, terminal style, floating-image
setting, weeb policy and sidebar tab visibility.
"""

from __future__ import annotations

import configparser
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
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
    weeb_wallpaper = str(weeb_folder / "Makima.jpg") if (weeb_folder / "Makima.jpg").exists() else current_wallpaper
    sober_wallpaper = str(sober_folder / "highlands-grid.jpg") if (sober_folder / "highlands-grid.jpg").exists() else current_wallpaper

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
    data["profiles"][profile_id] = profile
    save_json(PROFILES_FILE, data)
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
        while target.exists() and target.resolve() != source.resolve():
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
