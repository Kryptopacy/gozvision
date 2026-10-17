import http.server
import socketserver
import os
import mimetypes

PORT = 8085
DIST_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "dist"))

mimetypes.add_type("application/wasm", ".wasm")
mimetypes.add_type("application/javascript", ".js")
mimetypes.add_type("application/json", ".json")
mimetypes.add_type("image/x-icon", ".ico")
mimetypes.add_type("image/png", ".png")

class GozVisionHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIST_DIR, **kwargs)

    def end_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "credentialless")
        super().end_headers()

    def do_GET(self):
        # Strip query parameters
        clean_path = self.path.split("?")[0]
        full_path = os.path.normpath(os.path.join(DIST_DIR, clean_path.lstrip("/")))

        # If file exists on disk, let default handler serve it
        if os.path.exists(full_path) and os.path.isfile(full_path):
            return super().do_GET()

        # SPA routing fallbacks matching vercel.json
        if clean_path.startswith("/clinic"):
            self.path = "/clinic/index.html"
        elif clean_path.startswith("/patient"):
            self.path = "/patient/index.html"
        else:
            self.path = "/index.html"
        return super().do_GET()

if __name__ == "__main__":
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("", PORT), GozVisionHandler) as httpd:
        print(f"GozVision Local Production Server running at http://localhost:{PORT}")
        httpd.serve_forever()
