"""Tiny API in front of the store service. /items proxies to the store.

Seeded resilience bug: the call to the store has no timeout and no fallback, so a store that
stops answering makes /items hang instead of failing fast with a 503.
"""
import json
import os
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

STORE_URL = os.environ.get("STORE_URL", "http://store:8081/items")


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/health":
            self.reply(200, {"status": "ok"})
        elif self.path == "/items":
            with urllib.request.urlopen(STORE_URL) as resp:  # no timeout: the seeded bug
                items = json.load(resp)
            self.reply(200, {"items": items})
        else:
            self.reply(404, {"error": "not found"})

    def reply(self, code, body):
        data = json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, fmt, *args):
        print("api: " + fmt % args, flush=True)


if __name__ == "__main__":
    print("api: listening on :8080", flush=True)
    ThreadingHTTPServer(("", 8080), Handler).serve_forever()
