#!/usr/bin/env python3
"""One-time Spotify authorization for direct recommendation playback."""

from __future__ import annotations

import base64
import json
import os
import secrets
import subprocess
import sys
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

CLIENT_ID = os.environ.get("SPOTIFY_CLIENT_ID", "")
CLIENT_SECRET = os.environ.get("SPOTIFY_CLIENT_SECRET", "")
REDIRECT_URI = "http://127.0.0.1:8888/callback"
SCOPES = "user-read-playback-state user-modify-playback-state"
TOKEN_FILE = Path.home() / ".config" / "illogical-impulse" / "spotify_token.json"
STATE = secrets.token_urlsafe(24)


def load_session_credentials() -> None:
    global CLIENT_ID, CLIENT_SECRET
    if CLIENT_ID and CLIENT_SECRET:
        return

    for path in (
        Path.home() / ".config" / "uwsm" / "env",
        Path.home() / ".config" / "uwsm" / "env.local",
    ):
        try:
            for raw_line in path.read_text(encoding="utf-8").splitlines():
                line = raw_line.strip()
                if line.startswith("export "):
                    line = line[7:].strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                key, value = line.split("=", 1)
                if key == "SPOTIFY_CLIENT_ID":
                    CLIENT_ID = value.strip().strip('"').strip("'")
                elif key == "SPOTIFY_CLIENT_SECRET":
                    CLIENT_SECRET = value.strip().strip('"').strip("'")
        except OSError:
            continue


class CallbackHandler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path != "/callback":
            self.send_response(404)
            self.end_headers()
            return

        params = urllib.parse.parse_qs(parsed.query)
        error = params.get("error", [""])[0]
        code = params.get("code", [""])[0]
        returned_state = params.get("state", [""])[0]

        if error:
            self._respond(f"Spotify authorization failed: {error}")
            self.server.result = {"error": error}
            return
        if returned_state != STATE:
            self._respond("Invalid authorization state. Please try again.")
            self.server.result = {"error": "state mismatch"}
            return
        if not code:
            self._respond("No authorization code received.")
            self.server.result = {"error": "missing code"}
            return

        self._respond("Spotify authorization complete. You can close this tab.")
        self.server.result = {"code": code}

    def _respond(self, message: str) -> None:
        body = (
            "<html><body style='background:#111;color:#eee;font-family:sans-serif;"
            "padding:40px'><h2>Illogical Impulse</h2><p>"
            + message
            + "</p></body></html>"
        ).encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format: str, *args) -> None:
        pass


def exchange_code(code: str) -> dict:
    credentials = base64.b64encode(f"{CLIENT_ID}:{CLIENT_SECRET}".encode()).decode()
    request = urllib.request.Request(
        "https://accounts.spotify.com/api/token",
        data=urllib.parse.urlencode({
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": REDIRECT_URI,
        }).encode(),
        headers={
            "Authorization": f"Basic {credentials}",
            "Content-Type": "application/x-www-form-urlencoded",
        },
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=15) as response:
        return json.loads(response.read().decode("utf-8"))


def main() -> None:
    load_session_credentials()
    if not CLIENT_ID or not CLIENT_SECRET:
        print("Set SPOTIFY_CLIENT_ID and SPOTIFY_CLIENT_SECRET in ~/.config/uwsm/env first.")
        sys.exit(1)

    authorize_url = "https://accounts.spotify.com/authorize?" + urllib.parse.urlencode({
        "client_id": CLIENT_ID,
        "response_type": "code",
        "redirect_uri": REDIRECT_URI,
        "scope": SCOPES,
        "state": STATE,
        "show_dialog": "true",
    })

    print("Make sure this redirect URI is registered in your Spotify app settings:")
    print(f"  {REDIRECT_URI}")
    print()
    print("Opening Spotify authorization page...")
    subprocess.Popen(
        ["xdg-open", authorize_url],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )

    server = HTTPServer(("127.0.0.1", 8888), CallbackHandler)
    server.result = {}
    print("Waiting for authorization...")
    server.handle_request()
    server.server_close()

    result = server.result
    if "code" not in result:
        print(f"Authorization failed: {result.get('error', 'unknown error')}")
        sys.exit(1)

    try:
        token_data = exchange_code(result["code"])
    except Exception as error:
        print(f"Could not exchange authorization code: {error}")
        sys.exit(1)

    refresh_token = token_data.get("refresh_token", "")
    if not refresh_token:
        print("Spotify did not return a refresh token.")
        sys.exit(1)

    TOKEN_FILE.parent.mkdir(parents=True, exist_ok=True)
    TOKEN_FILE.write_text(
        json.dumps({
            "refresh_token": refresh_token,
            "access_token": token_data.get("access_token", ""),
            "expires_at": token_data.get("expires_in", 3600),
            "scope": token_data.get("scope", SCOPES),
        }, indent=2),
        encoding="utf-8",
    )
    os.chmod(TOKEN_FILE, 0o600)

    print()
    print(f"Authorization saved to {TOKEN_FILE}")
    print("Recommendation playback will now use the Spotify Web API without opening Spotify.")


if __name__ == "__main__":
    main()
