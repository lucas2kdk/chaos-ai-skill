"""Tiny store service: GET /items returns a fixed list."""
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ITEMS = [{"id": 1, "name": "kettle"}, {"id": 2, "name": "lamp"}]


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        code, body = (200, ITEMS) if self.path == "/items" else (404, {"error": "not found"})
        data = json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, fmt, *args):
        print("store: " + fmt % args, flush=True)


if __name__ == "__main__":
    print("store: listening on :8081", flush=True)
    ThreadingHTTPServer(("", 8081), Handler).serve_forever()
