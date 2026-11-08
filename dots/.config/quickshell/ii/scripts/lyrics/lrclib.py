#!/usr/bin/env python3
"""Query LRCLIB for synced/plain lyrics and print JSON.

YouTube metadata is much noisier than Spotify metadata: titles often contain
"Artist - Song (Official Video)" and the MPRIS artist is the channel name. The
helper normalizes those values and tries a few artist/title pairs before giving
up, so YouTube playback gets the same lyrics support as Spotify.
"""

from __future__ import annotations

import html
import json
import re
import sys
import urllib.error
import urllib.parse
import urllib.request

USER_AGENT = "illogical-impulse-lyrics/1.0 (https://github.com/end-4/dots-hyprland)"

DECORATION_KEYWORDS = (
    "official video",
    "official music video",
    "official audio",
    "official lyric video",
    "lyric video",
    "lyrics video",
    "videoclip",
    "video oficial",
    "video lyric",
    "visualizer",
    "visualiser",
    "audio",
    "en vivo",
    "live",
    "directo",
    "remaster",
    "remastered",
    "music video",
    "m/v",
    "mv",
    "4k",
    "8k",
    "hd",
    "hq",
    "performance",
    "subtitulado",
    "subtitulada",
    "traducido",
    "traduccion",
    "espanol",
    "español",
    "english",
)

TITLE_SEPARATORS = (" - ", " – ", " — ", " | ")


def normalize_space(value: str) -> str:
    return re.sub(r"\s+", " ", value).strip()


def is_unknown(value: str) -> bool:
    lowered = value.strip().lower()
    return (
        lowered in ("", "unknown artist", "unknown title", "unknown album")
        or "unknown" in lowered
        or "desconocid" in lowered
    )


def normalize_duration(value: str) -> str:
    try:
        seconds = float(value)
    except (TypeError, ValueError):
        return ""
    if seconds > 3600:
        seconds /= 1_000_000
    if 1 <= seconds <= 3600:
        return str(int(round(seconds)))
    return ""


def is_decoration(value: str) -> bool:
    lowered = normalize_space(value).lower()
    if not lowered:
        return True
    return any(keyword in lowered for keyword in DECORATION_KEYWORDS)


def strip_brackets(value: str) -> str:
    def replace(match: re.Match) -> str:
        return "" if is_decoration(match.group(1)) else match.group(0)

    return re.sub(r"\s*[\[(（]([^)\]}）]*)[\]\)）]", replace, value)


def clean_title(value: str) -> str:
    title = html.unescape(value or "")
    title = strip_brackets(title)
    title = re.sub(
        r"\s*[-–—|]\s*(?:official\s+)?(?:music\s+)?"
        r"(?:video|audio|videoclip|visuali[sz]er)\s*$",
        "",
        title,
        flags=re.IGNORECASE,
    )
    title = re.sub(r"\s*[-–—|]\s*YouTube(?:\s+Music)?\s*$", "", title, flags=re.IGNORECASE)
    return normalize_space(title).strip(" -–—|")


def clean_artist(value: str) -> str:
    artist = html.unescape(value or "")
    artist = re.sub(r"\s*[-–—]\s*Topic\s*$", "", artist, flags=re.IGNORECASE)
    artist = re.sub(r"VEVO$", "", artist, flags=re.IGNORECASE)
    artist = re.sub(r"\s*&\s*", " & ", artist)
    return normalize_space(artist)


def simplified(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", value.lower())


def similar(left: str, right: str) -> bool:
    left_key = simplified(left)
    right_key = simplified(right)
    if not left_key or not right_key:
        return False
    return left_key == right_key or left_key in right_key or right_key in left_key


def split_title(title: str) -> tuple[str, str]:
    for separator in TITLE_SEPARATORS:
        if separator in title:
            left, right = title.split(separator, 1)
            left, right = left.strip(), right.strip()
            if left and right:
                return left, right
    return "", ""


def build_candidates(artist: str, title: str) -> tuple[list[tuple[str, str]], list[str]]:
    artist = clean_artist(artist)
    if is_unknown(artist):
        artist = ""
    title = clean_title(title)
    if is_unknown(title):
        title = ""

    candidates: list[tuple[str, str]] = []

    def add(candidate_artist: str, candidate_title: str) -> None:
        candidate_artist = clean_artist(candidate_artist)
        candidate_title = clean_title(candidate_title)
        if not candidate_title:
            return
        pair = (candidate_artist, candidate_title)
        if pair not in candidates:
            candidates.append(pair)

    left, right = split_title(title)
    derived_title = ""
    if left and right:
        if artist and similar(right, artist) and not similar(left, artist):
            add(right, left)
            derived_title = left
        else:
            add(left, right)
            derived_title = right

    add(artist, title)

    if not candidates and title:
        candidates.append(("", title))

    title_only = []
    for value in (derived_title, title):
        if value and value not in title_only:
            title_only.append(value)
    return candidates, title_only


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


def find_lyrics(artist: str, title: str, album: str, duration: str):
    candidates, title_only = build_candidates(artist, title)
    duration = normalize_duration(duration)

    for candidate_artist, candidate_title in candidates:
        if candidate_artist and candidate_title:
            params = {
                "artist_name": candidate_artist,
                "track_name": candidate_title,
            }
            if album and not is_unknown(album):
                params["album_name"] = album
            if duration and duration not in ("0", "0.0"):
                params["duration"] = duration
            exact_url = "https://lrclib.net/api/get?" + urllib.parse.urlencode(params)
            exact = fetch_json(exact_url)
            if has_lyrics(exact):
                return exact

        search_params = {"track_name": candidate_title}
        if candidate_artist:
            search_params["artist_name"] = candidate_artist
        search_url = "https://lrclib.net/api/search?" + urllib.parse.urlencode(search_params)
        results = fetch_json(search_url)
        if isinstance(results, list):
            for result in results:
                if has_lyrics(result):
                    return result

    for candidate_title in title_only:
        search_url = "https://lrclib.net/api/search?" + urllib.parse.urlencode(
            {"track_name": candidate_title}
        )
        results = fetch_json(search_url)
        if isinstance(results, list):
            for result in results:
                if has_lyrics(result):
                    return result

    return {
        "error": "No lyrics found",
        "syncedLyrics": None,
        "plainLyrics": None,
    }


def main() -> None:
    artist = sys.argv[1] if len(sys.argv) > 1 else ""
    title = sys.argv[2] if len(sys.argv) > 2 else ""
    album = sys.argv[3] if len(sys.argv) > 3 else ""
    duration = sys.argv[4] if len(sys.argv) > 4 else ""

    result = find_lyrics(artist, title, album, duration)
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
