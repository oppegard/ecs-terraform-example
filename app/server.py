import json
import os
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


PORT = int(os.environ.get("PORT", "8080"))
APP_NAME = os.environ.get("APP_NAME", "ecs-terraform-example")
APP_ENV = os.environ.get("APP_ENV", "local")


class Handler(BaseHTTPRequestHandler):
    def _write_json(self, status: HTTPStatus, payload: dict) -> None:
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:
        if self.path == "/":
            self._write_json(
                HTTPStatus.OK,
                {
                    "service": APP_NAME,
                    "environment": APP_ENV,
                    "message": "hello from ecs",
                },
            )
            return

        if self.path == "/health":
            self._write_json(
                HTTPStatus.OK,
                {
                    "status": "ok",
                    "service": APP_NAME,
                    "environment": APP_ENV,
                },
            )
            return

        self._write_json(
            HTTPStatus.NOT_FOUND,
            {
                "error": "not_found",
                "path": self.path,
            },
        )

    def log_message(self, format: str, *args) -> None:
        return


def main() -> None:
    server = ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    server.serve_forever()


if __name__ == "__main__":
    main()
