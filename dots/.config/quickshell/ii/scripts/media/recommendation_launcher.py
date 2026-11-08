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
            open_spotify_uri(uri)
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
