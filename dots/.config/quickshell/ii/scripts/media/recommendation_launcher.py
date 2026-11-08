#!/usr/bin/env python3
"""Open a recommended track on the platform that is currently playing."""

from __future__ import annotations

import base64
import json
import os
import re
import shutil
import subprocess
import sys
import time
import urllib.parse
import urllib.request
from datetime import datetime
from pathlib import Path

USER_AGENT = (
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/124.0 Safari/537.36"
)
LOG_FILE = Path.home() / ".cache" / "quickshell" / "recommendation_launcher.log"
TOKEN_FILE = Path.home() / ".config" / "illogical-impulse" / "spotify_token.json"
PLAYBACK_STATE_FILE = Path.home() / ".cache" / "quickshell" / "spotify_playback_state.json"
ENV_FILES = [
    Path.home() / ".config" / "uwsm" / "env",
    Path.home() / ".config" / "uwsm" / "env.local",
]


def load_session_credentials() -> None:
    """Fallback for environments that do not propagate UWSM variables."""
    if os.environ.get("SPOTIFY_CLIENT_ID") and os.environ.get("SPOTIFY_CLIENT_SECRET"):
        return

    for path in ENV_FILES:
        try:
            for raw_line in path.read_text(encoding="utf-8").splitlines():
                line = raw_line.strip()
                if line.startswith("export "):
                    line = line[7:].strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                key, value = line.split("=", 1)
                if key not in ("SPOTIFY_CLIENT_ID", "SPOTIFY_CLIENT_SECRET"):
                    continue
                value = value.strip().strip('"').strip("'")
                if value:
                    os.environ[key] = value
        except OSError:
            continue


def log(message: str) -> None:
    try:
        LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
        with LOG_FILE.open("a", encoding="utf-8") as handle:
            handle.write(f"{datetime.now().isoformat(timespec='seconds')} {message}\n")
    except Exception:
        pass


def hyprctl_json(args: list[str]) -> dict:
    try:
        output = subprocess.check_output(["hyprctl", *args], text=True, timeout=4)
        return json.loads(output)
    except Exception:
        return {}


def capture_focus_state() -> dict:
    active = hyprctl_json(["activewindow", "-j"])
    if active.get("address"):
        return {
            "window": f"address:{active['address']}",
            "class": str(active.get("class", "")),
        }

    monitors = hyprctl_json(["monitors", "-j"])
    focused = next((monitor for monitor in monitors if monitor.get("focused")), None)
    if not focused:
        return {}
    workspace = focused.get("activeWorkspace", {}).get("id", "")
    return {
        "workspace": str(workspace),
        "monitor": str(focused.get("name", "")),
        "class": "",
    }


def restore_focus_state(state: dict) -> None:
    if not state:
        return
    try:
        if state.get("window"):
            subprocess.run(
                ["hyprctl", "dispatch", f'hl.dsp.focus({{window="{state["window"]}"}})'],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=4,
            )
        elif state.get("workspace"):
            subprocess.run(
                ["hyprctl", "dispatch", f'hl.dsp.focus({{workspace="{state["workspace"]}"}})'],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=4,
            )
        log(f"restored focus to {state.get('window') or state.get('workspace')}")
    except Exception as error:
        log(f"focus restore failed: {type(error).__name__}: {error}")


def restore_focus_if_stolen(state: dict) -> None:
    if not state or str(state.get("class", "")).lower() == "spotify":
        return

    deadline = time.monotonic() + 1.2
    while time.monotonic() < deadline:
        active = hyprctl_json(["activewindow", "-j"])
        if str(active.get("class", "")).lower() == "spotify":
            restore_focus_state(state)
            return
        time.sleep(0.025)


def set_spotify_no_focus(enabled: bool) -> bool:
    """Temporarily stop Spotify from raising its window on MPRIS OpenUri."""
    if enabled:
        code = (
            'if not _recommendation_spotify_no_focus then '
            '_recommendation_spotify_no_focus = hl.window_rule({'
            'name="recommendation-spotify-no-focus", '
            'match={class="^(Spotify)$"}, no_focus=true}) '
            'else _recommendation_spotify_no_focus:set_enabled(true) end'
        )
    else:
        code = (
            'if _recommendation_spotify_no_focus then '
            '_recommendation_spotify_no_focus:set_enabled(false) end'
        )
    try:
        result = subprocess.run(
            ["hyprctl", "eval", code],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=4,
        )
        return result.returncode == 0
    except Exception as error:
        log(f"spotify no-focus rule failed: {type(error).__name__}: {error}")
        return False


def set_animations(enabled: bool) -> None:
    try:
        subprocess.run(
            ["hyprctl", "keyword", "animations:enabled", "true" if enabled else "false"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=4,
        )
    except Exception:
        pass


def recommend_without_focus(uri: str) -> bool:
    """Fallback path: start the track through MPRIS without raising Spotify."""
    focus_state = capture_focus_state()
    no_focus_rule = set_spotify_no_focus(True)
    if not no_focus_rule:
        # Older Hyprland versions may not expose hl.window_rule through
        # hyprctl eval. Hide the workspace switch instead.
        set_animations(False)
    try:
        open_spotify_uri(uri)
        restore_focus_state(focus_state)
    finally:
        if no_focus_rule:
            set_spotify_no_focus(False)
        else:
            time.sleep(0.05)
            set_animations(True)
    return True


def open_url(url: str) -> None:
    log(f"open_url {url}")
    subprocess.Popen(
        ["xdg-open", url],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def open_spotify_uri(uri: str) -> None:
    """Ask the running Spotify player to open the track, if possible."""
    if shutil.which("playerctl"):
        try:
            result = subprocess.run(
                ["playerctl", "open", uri],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=8,
            )
            if result.returncode == 0:
                log(f"playerctl open ok {uri}")
                return
        except Exception as error:
            log(f"playerctl open failed: {type(error).__name__}: {error}")
    open_url(uri)


def spotify_token() -> str:
    client_id = os.environ.get("SPOTIFY_CLIENT_ID", "")
    client_secret = os.environ.get("SPOTIFY_CLIENT_SECRET", "")
    log(f"spotify credentials present={bool(client_id and client_secret)}")
    if not client_id or not client_secret:
        return ""

    try:
        credentials = base64.b64encode(f"{client_id}:{client_secret}".encode()).decode()
        token_request = urllib.request.Request(
            "https://accounts.spotify.com/api/token",
            data=b"grant_type=client_credentials",
            headers={
                "Authorization": f"Basic {credentials}",
                "Content-Type": "application/x-www-form-urlencoded",
                "User-Agent": USER_AGENT,
            },
            method="POST",
        )
        with urllib.request.urlopen(token_request, timeout=12) as response:
            token = json.loads(response.read().decode("utf-8")).get("access_token", "")
        log(f"spotify token {'ok' if token else 'missing'}")
        return token
    except Exception as error:
        log(f"spotify token error: {type(error).__name__}: {error}")
        return ""


def spotify_search(token: str, query: str) -> str:
    search_url = (
        "https://api.spotify.com/v1/search?type=track&limit=1&q="
        + urllib.parse.quote(query)
    )
    search_request = urllib.request.Request(
        search_url,
        headers={"Authorization": f"Bearer {token}", "User-Agent": USER_AGENT},
    )
    with urllib.request.urlopen(search_request, timeout=12) as response:
        data = json.loads(response.read().decode("utf-8"))
    items = data.get("tracks", {}).get("items", [])
    uri = items[0].get("uri", "") if items else ""
    log(f"spotify search {query!r} -> {uri or 'no result'}")
    return uri


def spotify_track_uri(queries: list[str]) -> str:
    """Resolve a track URI using Spotify client credentials when available."""
    token = spotify_token()
    if not token:
        return ""

    for attempt in range(2):
        for query in queries:
            if not query:
                continue
            try:
                uri = spotify_search(token, query)
                if uri:
                    return uri
            except Exception as error:
                log(f"spotify search error ({type(error).__name__}): {error}")
        if attempt == 0:
            time.sleep(1)
    return ""


def spotify_user_token() -> str:
    try:
        data = json.loads(TOKEN_FILE.read_text(encoding="utf-8"))
    except Exception:
        log("spotify user token not configured; run spotify_auth.py")
        return ""

    refresh_token = data.get("refresh_token", "")
    if not refresh_token:
        return ""

    client_id = os.environ.get("SPOTIFY_CLIENT_ID", "")
    client_secret = os.environ.get("SPOTIFY_CLIENT_SECRET", "")
    if not client_id or not client_secret:
        log("spotify user token refresh requires client credentials")
        return ""

    try:
        credentials = base64.b64encode(f"{client_id}:{client_secret}".encode()).decode()
        request = urllib.request.Request(
            "https://accounts.spotify.com/api/token",
            data=urllib.parse.urlencode({
                "grant_type": "refresh_token",
                "refresh_token": refresh_token,
            }).encode(),
            headers={
                "Authorization": f"Basic {credentials}",
                "Content-Type": "application/x-www-form-urlencoded",
            },
            method="POST",
        )
        with urllib.request.urlopen(request, timeout=12) as response:
            refreshed = json.loads(response.read().decode("utf-8"))
        access_token = refreshed.get("access_token", "")
        if refreshed.get("refresh_token"):
            data["refresh_token"] = refreshed["refresh_token"]
        if access_token:
            data["access_token"] = access_token
            TOKEN_FILE.write_text(json.dumps(data, indent=2), encoding="utf-8")
            os.chmod(TOKEN_FILE, 0o600)
        log(f"spotify user token {'ok' if access_token else 'missing'}")
        return access_token
    except Exception as error:
        log(f"spotify user token error: {type(error).__name__}: {error}")
        return ""


def web_api_playback_allowed() -> bool:
    """Check whether the optional Remote Play path should be attempted."""
    if os.environ.get("SPOTIFY_FORCE_WEB_PLAYBACK") != "1":
        return False
    try:
        data = json.loads(PLAYBACK_STATE_FILE.read_text(encoding="utf-8"))
    except Exception:
        return True
    if data.get("ok"):
        return True
    try:
        checked_at = float(data.get("checked_at", 0))
    except (TypeError, ValueError):
        checked_at = 0
    if time.time() - checked_at > 86400:
        return True
    log("spotify web playback disabled after a previous failure; using MPRIS fallback")
    return False


def record_web_api_playback(ok: bool) -> None:
    try:
        PLAYBACK_STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
        PLAYBACK_STATE_FILE.write_text(
            json.dumps({"ok": ok, "checked_at": time.time()}),
            encoding="utf-8",
        )
    except Exception as error:
        log(f"spotify playback state write failed: {type(error).__name__}: {error}")


def spotify_play_track(uri: str) -> bool:
    token = spotify_user_token()
    if not token:
        return False

    headers = {"Authorization": f"Bearer {token}", "User-Agent": USER_AGENT}
    try:
        devices_request = urllib.request.Request(
            "https://api.spotify.com/v1/me/player/devices",
            headers=headers,
        )
        with urllib.request.urlopen(devices_request, timeout=12) as response:
            devices = json.loads(response.read().decode("utf-8")).get("devices", [])
    except Exception as error:
        log(f"spotify device lookup error: {type(error).__name__}: {error}")
        return False

    if not devices:
        log("spotify web playback: no devices")
        return False

    active_device = next((item for item in devices if item.get("is_active")), None)
    if active_device:
        device = active_device
    else:
        device = next((item for item in devices if item.get("type") == "Computer"), devices[0])
    device_id = device.get("id", "")
    if not device_id:
        return False

    if not active_device:
        try:
            transfer = urllib.request.Request(
                "https://api.spotify.com/v1/me/player",
                data=json.dumps({"device_ids": [device_id], "play": False}).encode(),
                headers={
                    "Authorization": f"Bearer {token}",
                    "Content-Type": "application/json",
                    "User-Agent": USER_AGENT,
                },
                method="PUT",
            )
            with urllib.request.urlopen(transfer, timeout=12) as response:
                log(f"spotify transfer playback {response.status}")
        except Exception as error:
            log(f"spotify transfer error: {type(error).__name__}: {error}")

    try:
        request = urllib.request.Request(
            "https://api.spotify.com/v1/me/player/play?device_id=" + urllib.parse.quote(device_id),
            data=json.dumps({"uris": [uri]}).encode(),
            headers={
                "Authorization": f"Bearer {token}",
                "Content-Type": "application/json",
                "User-Agent": USER_AGENT,
            },
            method="PUT",
        )
        with urllib.request.urlopen(request, timeout=12) as response:
            if response.status not in (200, 202, 204):
                log(f"spotify web playback unexpected status {response.status}")
                return False
    except Exception as error:
        log(f"spotify web playback error: {type(error).__name__}: {error}")
        return False

    # A 204 only means the command was accepted. Verify that the player really
    # switched to the requested track before skipping the fallback path.
    time.sleep(0.9)
    try:
        state_request = urllib.request.Request(
            "https://api.spotify.com/v1/me/player",
            headers=headers,
        )
        with urllib.request.urlopen(state_request, timeout=12) as response:
            if response.status == 204:
                log("spotify web playback did not activate a device")
                return False
            state = json.loads(response.read().decode("utf-8"))
        item = state.get("item") or {}
        if state.get("is_playing") and item.get("uri") == uri:
            log(f"spotify web playback ok {uri} on {device.get('name', device_id)}")
            return True
        log(
            "spotify web playback was accepted but did not start "
            f"(playing={state.get('is_playing')} item={item.get('uri')!r})"
        )
    except Exception as error:
        log(f"spotify playback verification error: {type(error).__name__}: {error}")

    return False


def first_youtube_video_id(query: str) -> str:
    search_url = "https://www.youtube.com/results?search_query=" + urllib.parse.quote_plus(query)
    request = urllib.request.Request(search_url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=12) as response:
        html = response.read().decode("utf-8", errors="replace")
    match = re.search(r'"videoId":"([A-Za-z0-9_-]{11})"', html)
    return match.group(1) if match else ""


def main() -> None:
    if len(sys.argv) < 4:
        log("missing arguments")
        return

    load_session_credentials()
    platform = sys.argv[1].lower()
    title = sys.argv[2].strip()
    artist = sys.argv[3].strip()
    isrc = sys.argv[4].strip() if len(sys.argv) > 4 else ""
    query = f"{title} {artist}".strip()
    log(f"launch platform={platform} title={title!r} artist={artist!r} isrc={isrc!r}")

    if platform == "spotify":
        queries = []
        if isrc:
            queries.append(f"isrc:{isrc}")
        queries.extend([query, title, artist])
        uri = spotify_track_uri(queries)
        if uri:
            if TOKEN_FILE.exists() and web_api_playback_allowed():
                if spotify_play_track(uri):
                    record_web_api_playback(True)
                    return
                record_web_api_playback(False)
            # Start the track through MPRIS with a temporary Hyprland
            # no_focus rule, so Spotify does not raise itself or switch
            # workspaces. Restore focus as a safety net.
            recommend_without_focus(uri)
        else:
            log("spotify direct lookup failed; falling back to search")
            open_url("spotify:search:" + urllib.parse.quote(query))
        return

    video_id = ""
    try:
        video_id = first_youtube_video_id(query)
        log(f"youtube query={query!r} video={video_id or 'none'}")
    except Exception as error:
        log(f"youtube search error: {type(error).__name__}: {error}")

    if video_id:
        host = "music.youtube.com" if platform == "youtube-music" else "www.youtube.com"
        open_url(f"https://{host}/watch?v={video_id}")
        return

    if platform == "youtube-music":
        open_url("https://music.youtube.com/search?q=" + urllib.parse.quote_plus(query))
    else:
        open_url("https://www.youtube.com/results?search_query=" + urllib.parse.quote_plus(query))


if __name__ == "__main__":
    main()
