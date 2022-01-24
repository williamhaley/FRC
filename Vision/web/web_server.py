import socketserver
from http.server import HTTPServer, BaseHTTPRequestHandler

def run_web_server_forever(image_bytes_reader=None):
  class CamHandler(BaseHTTPRequestHandler):
    def do_GET(self):
      if self.path.endswith("cam.mjpg"):
        self.send_response(200)
        self.send_header(
          "Content-type",
          "multipart/x-mixed-replace; boundary=--jpgboundary"
        )
        self.end_headers()

        while True:
          try:
            if image_bytes_reader is None:
              continue

            image_bytes = image_bytes_reader()
            if image_bytes is None:
              continue

            self.send_header("Content-type", "image/jpeg")
            self.send_header("Content-length", len(image_bytes))
            self.end_headers()

            self.wfile.write(image_bytes)
            self.wfile.write(b"\r\n--jpgboundary\r\n")
          except KeyboardInterrupt:
            self.wfile.write(b"\r\n--jpgboundary--\r\n")
            break
          except BrokenPipeError:
            continue
        return

  class ThreadedHTTPServer(socketserver.ThreadingMixIn, HTTPServer):
    """Handle requests in a separate thread."""

  try:
    server = ThreadedHTTPServer(("localhost", 8081), CamHandler)
    print("server started at http://127.0.0.1:8081/cam.mjpg")
    server.serve_forever()
  except KeyboardInterrupt:
    server.socket.close()
