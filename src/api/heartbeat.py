"""Vercel serverless function: receive a heart-rate reading and broadcast it.

The iOS app POSTs JSON here; this function publishes it to a **public** Pusher
channel `heartrate-{shareId}` using the Pusher REST API. The Pusher secret lives
only in Vercel environment variables and never reaches any client.

Required environment variables (set in Vercel → Settings → Environment Variables):
    PUSHER_APP_ID, PUSHER_KEY, PUSHER_SECRET, PUSHER_CLUSTER
"""

import json
import os
import re
from http.server import BaseHTTPRequestHandler

import pusher

SHARE_ID_RE = re.compile(r"^[A-Za-z0-9]{4,32}$")


def _pusher_client() -> pusher.Pusher:
    return pusher.Pusher(
        app_id=os.environ["PUSHER_APP_ID"],
        key=os.environ["PUSHER_KEY"],
        secret=os.environ["PUSHER_SECRET"],
        cluster=os.environ["PUSHER_CLUSTER"],
        ssl=True,
    )


class handler(BaseHTTPRequestHandler):
    def _send(self, status: int, body: dict) -> None:
        payload = json.dumps(body).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def do_POST(self) -> None:
        try:
            length = int(self.headers.get("Content-Length", 0))
            raw = self.rfile.read(length) if length else b"{}"
            data = json.loads(raw or b"{}")
        except (ValueError, json.JSONDecodeError):
            return self._send(400, {"error": "invalid JSON body"})

        share_id = str(data.get("shareId", "")).strip()
        if not SHARE_ID_RE.match(share_id):
            return self._send(400, {"error": "invalid or missing shareId"})

        try:
            bpm = int(data.get("bpm"))
        except (TypeError, ValueError):
            return self._send(400, {"error": "bpm must be an integer"})
        if not 20 <= bpm <= 300:
            return self._send(400, {"error": "bpm out of range (20-300)"})

        timestamp = str(data.get("timestamp", ""))
        source = str(data.get("source", "unknown"))[:64]

        try:
            _pusher_client().trigger(
                f"heartrate-{share_id}",
                "heartrate-update",
                {
                    "bpm": bpm,
                    "timestamp": timestamp,
                    "source": source,
                    "shareId": share_id,
                },
            )
        except KeyError as exc:
            return self._send(500, {"error": f"server misconfigured: missing {exc}"})
        except Exception as exc:  # noqa: BLE001 - surface Pusher errors to the caller
            return self._send(502, {"error": f"failed to publish: {exc}"})

        return self._send(200, {"ok": True})
