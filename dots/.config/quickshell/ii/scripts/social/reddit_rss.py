#!/usr/bin/env python3
"""Fetch a Reddit subreddit RSS feed and print it as JSON.

Reddit's public JSON endpoints are often blocked or rate limited, while the
Atom feed still works. This helper keeps the QML side simple and caches the
last successful response so the widget can keep showing posts when Reddit
temporarily returns HTTP 429.
"""

from __future__ import annotations

import html
import json
import os
import re
import sys
import urllib.request
import xml.etree.ElementTree as ET
from datetime import datetime

USER_AGENT = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0 Safari/537.36"
NS = {
    "a": "http://www.w3.org/2005/Atom",
    "media": "http://search.yahoo.com/mrss/",
}


def cache_path(subreddit: str) -> str:
    cache_dir = os.path.expanduser("~/.cache/quickshell/social")
    os.makedirs(cache_dir, exist_ok=True)
    safe_name = re.sub(r"[^A-Za-z0-9_]", "_", subreddit)
    return os.path.join(cache_dir, f"{safe_name}.json")


def normalize_subreddit(value: str) -> str:
    value = value.strip()
    value = re.sub(r"^r/", "", value, flags=re.IGNORECASE)
    value = value.strip("/")
    return re.sub(r"[^A-Za-z0-9_]", "", value)


def parse_timestamp(value: str) -> int:
    if not value:
        return 0
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
        return int(parsed.timestamp())
    except ValueError:
        return 0


def extract_thumbnail(entry: ET.Element, content: str) -> str:
    thumbnail = entry.find("media:thumbnail", NS)
    if thumbnail is not None:
        url = thumbnail.attrib.get("url", "")
        if url:
            return html.unescape(url)

    # Reddit usually includes the post image in the Atom content HTML.
    match = re.search(r'<img[^>]+src=["\']([^"\']+)["\']', html.unescape(content), re.IGNORECASE)
    if match:
        return html.unescape(match.group(1))
    return ""


def fetch(subreddit: str) -> dict:
    url = f"https://www.reddit.com/r/{subreddit}/new.rss"
    request = urllib.request.Request(
        url,
        headers={
            "User-Agent": USER_AGENT,
            "Accept": "application/rss+xml, application/atom+xml, application/xml;q=0.9, */*;q=0.8",
        },
    )
    with urllib.request.urlopen(request, timeout=20) as response:
        payload = response.read()

    root = ET.fromstring(payload)
    posts = []
    for entry in root.findall("a:entry", NS):
        title = html.unescape(entry.findtext("a:title", default="", namespaces=NS))
        link_node = entry.find("a:link", NS)
        link = link_node.attrib.get("href", "") if link_node is not None else ""
        author = entry.findtext("a:author/a:name", default="", namespaces=NS)
        author = author.removeprefix("/u/")
        updated = entry.findtext("a:updated", default="", namespaces=NS)
        content = entry.findtext("a:content", default="", namespaces=NS)

        posts.append(
            {
                "title": title,
                "author": author,
                "url": link,
                "thumbnail": extract_thumbnail(entry, content),
                "createdUtc": parse_timestamp(updated),
                "subreddit": f"r/{subreddit}",
            }
        )

    return {"subreddit": subreddit, "posts": posts, "cached": False}


def main() -> None:
    subreddit = normalize_subreddit(sys.argv[1] if len(sys.argv) > 1 else "unixporn")
    if not subreddit:
        print(json.dumps({"error": "Invalid subreddit", "posts": []}))
        return

    cached_file = cache_path(subreddit)
    try:
        result = fetch(subreddit)
        with open(cached_file, "w", encoding="utf-8") as handle:
            json.dump(result, handle, ensure_ascii=False)
        print(json.dumps(result, ensure_ascii=False))
    except Exception as error:
        if os.path.exists(cached_file):
            try:
                with open(cached_file, "r", encoding="utf-8") as handle:
                    cached = json.load(handle)
                cached["cached"] = True
                cached["error"] = str(error)
                print(json.dumps(cached, ensure_ascii=False))
                return
            except Exception:
                pass
        print(json.dumps({"error": str(error), "posts": [], "cached": False}))


if __name__ == "__main__":
    main()
