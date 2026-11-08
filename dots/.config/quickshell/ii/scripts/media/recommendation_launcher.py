#!/usr/bin/env python3
"""Open a recommended track on the platform that is currently playing."""

from __future__ import annotations

import base64
import json
import os
import re
import subprocess
import sys
import urllib.parse
import urllib.request

USER_AGENT = (
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/124.0 Safari/537.36"
)


def open_url(url: str) -> None:
    subprocess.Popen(
        ["xdg-open", url],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def spotify_track_uri(query: str) -> str:
    """Resolve a track URI using Spotify client credentials when available.

    Spotify does not allow anonymous track search. Set SPOTIFY_CLIENT_ID and
    SPOTIFY_CLIENT_SECRET in the session environment to enable direct playback.
    """
    client_id = os.environ.get("SPOTIFY_CLIENT_ID", "")
    client_secret = os.environ.get("SPOTIFY_CLIENT_SECRET", "")
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
        if not token:
            return ""

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
        return items[0].get("uri", "") if items else ""
    except Exception:
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
        return

    platform = sys.argv[1].lower()
    title = sys.argv[2].strip()
    artist = sys.argv[3].strip()
    query = f"{title} {artist}".strip()

    if platform == "spotify":
        uri = spotify_track_uri(query)
        if uri:
            open_url(uri)
        else:
            # Without API credentials Spotify only permits opening a search.
            open_url("spotify:search:" + urllib.parse.quote(query))
        return

    video_id = ""
    try:
        video_id = first_youtube_video_id(query)
    except Exception:
        pass

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
