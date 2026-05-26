"""Vercel serverless function: expose the *public* Pusher config to the web page.

Returns only the publishable key and cluster (both safe to expose) from
environment variables, so nothing sensitive — and no config at all — lives in the
web source. The secret is never returned.
"""

import json
import os
from http.server import BaseHTTPRequestHandler


class handler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        body = json.dumps(
            {
                "key": os.environ.get("PUSHER_KEY", ""),
                "cluster": os.environ.get("PUSHER_CLUSTER", ""),
            }
        ).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Cache-Control", "public, max-age=300")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)
