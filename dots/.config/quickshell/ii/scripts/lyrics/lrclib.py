#!/usr/bin/env python3
"""Query LRCLIB for synced/plain lyrics and print JSON.

The QML side passes artist, title, album and duration as separate arguments so
no shell quoting is involved. If the exact /api/get lookup fails, the helper
falls back to /api/search and picks the first result that has lyrics.
"""

from __future__ import annotations

import json
import sys
import urllib.error
import urllib.parse
import urllib.request

USER_AGENT = "illogical-impulse-lyrics/1.0 (https://github.com/end-4/dots-hyprland)"


def fetch_json(url: str):
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            return json.loads(response.read().decode("utf-8", errors="replace"))
    except urllib.error.HTTPError as error:
        try:
            return json.loads(error.read().decode("utf-8", errors="replace"))
        except Exception:
            return {"error": f"HTTP {error.code}"}
    except Exception as error:
        return {"error": str(error)}


def has_lyrics(data) -> bool:
    return isinstance(data, dict) and bool(data.get("syncedLyrics") or data.get("plainLyrics"))


def main() -> None:
    artist = sys.argv[1] if len(sys.argv) > 1 else ""
    title = sys.argv[2] if len(sys.argv) > 2 else ""
    album = sys.argv[3] if len(sys.argv) > 3 else ""
    duration = sys.argv[4] if len(sys.argv) > 4 else ""

    if not artist or not title:
        print(json.dumps({"error": "Missing artist or title", "syncedLyrics": None, "plainLyrics": None}))
        return

    get_params = {
        "artist_name": artist,
        "track_name": title,
    }
    if album:
        get_params["album_name"] = album
    if duration and duration not in ("0", "0.0"):
        get_params["duration"] = duration

    get_url = "https://lrclib.net/api/get?" + urllib.parse.urlencode(get_params)
    data = fetch_json(get_url)

    if not has_lyrics(data):
        search_params = {
            "artist_name": artist,
            "track_name": title,
        }
        search_url = "https://lrclib.net/api/search?" + urllib.parse.urlencode(search_params)
        results = fetch_json(search_url)
        if isinstance(results, list):
            for candidate in results:
                if has_lyrics(candidate):
                    data = candidate
                    break

    if not isinstance(data, dict):
        data = {"error": "Unexpected LRCLIB response", "syncedLyrics": None, "plainLyrics": None}

    print(json.dumps(data, ensure_ascii=False))


if __name__ == "__main__":
    main()
