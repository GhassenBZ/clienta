#!/usr/bin/env python3
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import os
from pathlib import Path
from urllib.parse import urlsplit


WEB_ROOT = Path(os.environ.get("VIKUNJA_FRONTEND_ROOT", "/var/www/vikunja"))


class FrontendHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(WEB_ROOT), **kwargs)

    def do_GET(self):
        if urlsplit(self.path).path == "/health":
            self._send_health(True)
            return
        super().do_GET()

    def do_HEAD(self):
        if urlsplit(self.path).path == "/health":
            self._send_health(False)
            return
        super().do_HEAD()

    def translate_path(self, path):
        translated = Path(super().translate_path(path))
        if translated.exists():
            return str(translated)
        if not Path(urlsplit(path).path).suffix:
            return str(WEB_ROOT / "index.html")
        return str(translated)

    def _send_health(self, include_body):
        body = b"ok\n"
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if include_body:
            self.wfile.write(body)


def main():
    ThreadingHTTPServer(("0.0.0.0", 80), FrontendHandler).serve_forever()


if __name__ == "__main__":
    main()
