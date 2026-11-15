import tempfile
import threading
import unittest
from http.server import ThreadingHTTPServer
from pathlib import Path
from unittest.mock import patch
from urllib.error import HTTPError
from urllib.request import urlopen

from vikunja import serve_frontend


class FrontendHandlerTests(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.web_root = Path(self.temp_dir.name) / "www"
        self.web_root.mkdir()
        (self.web_root / "index.html").write_text("Vikunja frontend")
        assets = self.web_root / "assets"
        assets.mkdir()
        (assets / "app.js").write_text("console.log('ok')")

        self.root_patch = patch.object(serve_frontend, "WEB_ROOT", self.web_root)
        self.root_patch.start()
        self.server = ThreadingHTTPServer(("127.0.0.1", 0), serve_frontend.FrontendHandler)
        self.thread = threading.Thread(target=self.server.serve_forever)
        self.thread.start()
        self.base_url = "http://127.0.0.1:{0}".format(self.server.server_port)

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()
        self.root_patch.stop()
        self.temp_dir.cleanup()

    def test_health_endpoint(self):
        with urlopen(self.base_url + "/health") as response:
            self.assertEqual(response.status, 200)
            self.assertEqual(response.read(), b"ok\n")

    def test_static_files_and_spa_routes(self):
        with urlopen(self.base_url + "/assets/app.js") as response:
            self.assertEqual(response.read(), b"console.log('ok')")
        with urlopen(self.base_url + "/projects/42") as response:
            self.assertEqual(response.read(), b"Vikunja frontend")
        with self.assertRaises(HTTPError) as error:
            urlopen(self.base_url + "/assets/missing.js")
        self.assertEqual(error.exception.code, 404)

    def test_path_traversal_is_not_served(self):
        outside_file = Path(self.temp_dir.name) / "secret.js"
        outside_file.write_text("not public")
        try:
            with self.assertRaises(HTTPError) as error:
                urlopen(self.base_url + "/%2e%2e/secret.js")
            self.assertEqual(error.exception.code, 404)
        finally:
            outside_file.unlink()


if __name__ == "__main__":
    unittest.main()
