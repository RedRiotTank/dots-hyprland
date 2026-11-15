#!/usr/bin/env python3
"""Fetch a stable number of Deezer recommendations for the current track."""

from __future__ import annotations

import json
import re
import sys
import time
import unicodedata
import urllib.parse
import urllib.request
from datetime import datetime
from pathlib import Path

USER_AGENT = (
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/124.0 Safari/537.36"
)
LOG_FILE = Path.home() / ".cache" / "quickshell" / "recommendations.log"
LOG_MAX_BYTES = 256 * 1024
DEFAULT_LIMIT = 8
SEARCH_LIMIT = 25
MAX_SECONDS = 18


def log(message: str) -> None:
    try:
        LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
        try:
            if LOG_FILE.stat().st_size > LOG_MAX_BYTES:
                LOG_FILE.replace(LOG_FILE.with_name(LOG_FILE.name + ".1"))
        except OSError:
            pass
        with LOG_FILE.open("a", encoding="utf-8") as handle:
            handle.write(f"{datetime.now().isoformat(timespec='seconds')} {message}\n")
    except Exception:
        pass


def api_json(url: str, deadline: float) -> dict:
    if time.monotonic() > deadline:
        return {}
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(request, timeout=8) as response:
            return json.loads(response.read().decode("utf-8", errors="replace"))
    except Exception as error:
        log(f"request failed {url}: {type(error).__name__}: {error}")
        return {}


def normalized(text: str) -> str:
    text = unicodedata.normalize("NFKD", text or "")
    text = text.encode("ascii", "ignore").decode("ascii")
    return re.sub(r"\s+", " ", text).strip().casefold()


def artists_from(artist: str) -> list[str]:
    """Split a multi-artist MPRIS string into individual names."""
    base = re.sub(
        r"\s+(?:feat\.?|ft\.?|featuring|with)\s+.*$",
        "",
        artist or "",
        flags=re.IGNORECASE,
    )
    parts = re.split(r"\s*[,;/&]\s*", base)
    result: list[str] = []
    for part in parts:
        part = part.strip()
        if part and normalized(part) not in {normalized(item) for item in result}:
            result.append(part)
    return result


def add_tracks(
    tracks: list[dict],
    selected: list[dict],
    seen: set[str],
    current_title: str,
    current_artists: list[str],
    limit: int,
) -> None:
    for track in tracks:
        if len(selected) >= limit:
            return
        if not isinstance(track, dict) or track.get("readable") is False:
            continue
        title = str(track.get("title") or "").strip()
        if not title:
            continue
        track_artist = str((track.get("artist") or {}).get("name") or "").strip()
        if normalized(title) == current_title:
            artist_norm = normalized(track_artist)
            if any(
                normalized(name) in artist_norm or artist_norm in normalized(name)
                for name in current_artists
                if name
            ):
                continue
        track_id = str(track.get("id") or "")
        track_key = f"track:{normalized(title)}|{normalized(track_artist)}"
        id_key = f"id:{track_id}" if track_id else track_key
        if id_key in seen or track_key in seen:
            continue
        seen.add(id_key)
        seen.add(track_key)
        selected.append(track)


def main() -> None:
    if len(sys.argv) < 3:
        print(json.dumps({"data": [], "error": "Missing track information"}))
        return

    title = sys.argv[1].strip()
    artist = sys.argv[2].strip()
    album = sys.argv[3].strip() if len(sys.argv) > 3 else ""
    try:
        limit = max(1, min(20, int(sys.argv[4]))) if len(sys.argv) > 4 else DEFAULT_LIMIT
    except ValueError:
        limit = DEFAULT_LIMIT

    log(f"start title={title!r} artist={artist!r} album={album!r} limit={limit}")
    if not title:
        print(json.dumps({"data": [], "error": ""}))
        return

    deadline = time.monotonic() + MAX_SECONDS
    current_title = normalized(title)
    artist_names = artists_from(artist)
    primary_artist = artist_names[0] if artist_names else artist
    selected: list[dict] = []
    seen: set[str] = set()
    successful_request = False
    primary_artist_id = ""

    def search(query: str) -> None:
        nonlocal successful_request
        if not query or len(selected) >= limit or time.monotonic() > deadline:
            return
        url = (
            "https://api.deezer.com/search?limit="
            + str(SEARCH_LIMIT)
            + "&q="
            + urllib.parse.quote(query)
        )
        data = api_json(url, deadline)
        if data:
            successful_request = True
        add_tracks(data.get("data", []), selected, seen, current_title, artist_names, limit)
        log(f"search {query!r} -> total={len(selected)}")

    def resolve_primary_artist() -> str:
        nonlocal successful_request
        if not primary_artist or time.monotonic() > deadline:
            return ""
        url = (
            "https://api.deezer.com/search/artist?limit=1&q="
            + urllib.parse.quote(primary_artist)
        )
        data = api_json(url, deadline)
        if data:
            successful_request = True
        items = data.get("data", [])
        return str(items[0].get("id", "")) if items else ""

    # Artist searches are the best source: they stay relevant and usually
    # provide more than enough tracks to fill the list.
    for name in artist_names[:2]:
        search(name)
    search(f"{title} {primary_artist}".strip())
    search(f"{album} {primary_artist}".strip() if album else "")

    if len(selected) < limit:
        primary_artist_id = resolve_primary_artist()
        if primary_artist_id:
            top_url = (
                f"https://api.deezer.com/artist/{primary_artist_id}/top?limit={SEARCH_LIMIT}"
            )
            top = api_json(top_url, deadline)
            if top:
                successful_request = True
            add_tracks(top.get("data", []), selected, seen, current_title, artist_names, limit)
            log(f"artist top {primary_artist!r} -> total={len(selected)}")

    # Last resort: tracks from related artists. This keeps the section useful
    # for artists with a very small catalogue instead of leaving it empty.
    if len(selected) < limit and primary_artist_id and time.monotonic() < deadline:
        related_url = (
            f"https://api.deezer.com/artist/{primary_artist_id}/related?limit=4"
        )
        related = api_json(related_url, deadline)
        if related:
            successful_request = True
        for related_artist in related.get("data", []):
            if len(selected) >= limit or time.monotonic() > deadline:
                break
            related_id = str(related_artist.get("id", ""))
            if not related_id:
                continue
            top_url = f"https://api.deezer.com/artist/{related_id}/top?limit=5"
            top = api_json(top_url, deadline)
            if top:
                successful_request = True
            add_tracks(top.get("data", []), selected, seen, current_title, artist_names, limit)
            log(
                f"related top {related_artist.get('name')!r} -> total={len(selected)}"
            )

    error = "" if selected or successful_request else "Could not load recommendations"
    log(f"done results={len(selected)} error={error!r}")
    print(json.dumps({"data": selected[:limit], "error": error}, ensure_ascii=False))


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        log(f"fatal: {type(error).__name__}: {error}")
        print(json.dumps({"data": [], "error": "Could not load recommendations"}))
