from __future__ import annotations

import importlib.util
from importlib.machinery import SourceFileLoader
import threading
import urllib.error
import urllib.request
from pathlib import Path

import pytest


SCRIPT = Path(__file__).parents[1] / "roles/linux_baseline/files/sre-textfile-exporter"
SPEC = importlib.util.spec_from_loader(
    "sre_textfile_exporter", SourceFileLoader("sre_textfile_exporter", str(SCRIPT))
)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


@pytest.fixture()
def exporter(tmp_path: Path):
    metric_dir = tmp_path / "metrics"
    metric_dir.mkdir()
    server = MODULE.MetricsServer(("127.0.0.1", 0), metric_dir)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        yield server, metric_dir
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=2)


def get(server, path: str) -> tuple[int, str, str]:
    address, port = server.server_address
    response = urllib.request.urlopen(f"http://{address}:{port}{path}", timeout=2)
    return response.status, response.headers["Content-Type"], response.read().decode()


def test_metrics_are_sorted_and_symlinks_are_ignored(exporter, tmp_path: Path) -> None:
    server, metric_dir = exporter
    (metric_dir / "z.prom").write_text("z_metric 2\n", encoding="utf-8")
    (metric_dir / "a.prom").write_text("a_metric 1\n", encoding="utf-8")
    outside = tmp_path / "outside.prom"
    outside.write_text("secret_metric 99\n", encoding="utf-8")
    (metric_dir / "linked.prom").symlink_to(outside)

    status, content_type, body = get(server, "/metrics")
    assert status == 200
    assert "version=0.0.4" in content_type
    assert body == "a_metric 1\nz_metric 2\n"


def test_health_and_unknown_paths(exporter) -> None:
    server, _ = exporter
    assert get(server, "/healthz") == (200, "text/plain; charset=utf-8", "ok\n")
    with pytest.raises(urllib.error.HTTPError) as error:
        get(server, "/not-found")
    assert error.value.code == 404
