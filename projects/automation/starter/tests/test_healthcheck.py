import json
import socket
import threading
import time
from collections import namedtuple
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import pytest

import healthcheck


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/slow":
            time.sleep(2)
        code = {"/ok": 200, "/fail": 500, "/slow": 200, "/moved": 302}.get(self.path, 404)
        self.send_response(code)
        if code == 302:
            self.send_header("Location", "/ok")
        self.end_headers()

    def log_message(self, *args):
        pass


@pytest.fixture(scope="module")
def server():
    srv = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    yield f"http://127.0.0.1:{srv.server_address[1]}"
    srv.shutdown()


def free_port():
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


def test_url_ok(server):
    r = healthcheck.check_url(server + "/ok", 2)
    assert r.ok and "200" in r.detail


def test_url_follows_redirect(server):
    assert healthcheck.check_url(server + "/moved", 2).ok


def test_url_http_error(server):
    r = healthcheck.check_url(server + "/fail", 2)
    assert not r.ok and "500" in r.detail


def test_url_connection_refused():
    r = healthcheck.check_url(f"http://127.0.0.1:{free_port()}/", 2)
    assert not r.ok and r.detail


def test_url_timeout(server):
    started = time.monotonic()
    r = healthcheck.check_url(server + "/slow", 0.5)
    assert not r.ok
    assert time.monotonic() - started < 1.9, "таймаут не сработал"


Usage = namedtuple("Usage", "total used free")


def test_disk_thresholds():
    assert healthcheck.check_disk("/", 90, usage=lambda p: Usage(100, 50, 50)).ok
    r = healthcheck.check_disk("/", 90, usage=lambda p: Usage(100, 95, 5))
    assert not r.ok and "95" in r.detail


def test_main_writes_state_and_exit_code(server, tmp_path, capsys):
    env = {"HEALTH_URLS": server + "/ok", "STATE_DIR": str(tmp_path), "DISK_MAX_PERCENT": "100"}
    assert healthcheck.main(env) == 0
    state = json.loads((tmp_path / "health.json").read_text())
    assert state["ok"] is True and state["checked_at"]
    assert [r["name"] for r in state["results"]][0] == server + "/ok"

    env["HEALTH_URLS"] = f"{server}/ok {server}/fail"
    assert healthcheck.main(env) == 1
    state = json.loads((tmp_path / "health.json").read_text())
    assert state["ok"] is False
    assert "FAIL" in capsys.readouterr().out
    assert [p.name for p in tmp_path.iterdir()] == ["health.json"], "временные файлы должны исчезать"
