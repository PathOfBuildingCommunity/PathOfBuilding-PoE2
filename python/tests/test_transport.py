"""/mcp host allow-list (no engine needed: initialize does not start PoB)."""

import pytest
from fastapi.testclient import TestClient

from pob2.web.app import create_app, mcp_transport_security

INIT = {
    "jsonrpc": "2.0",
    "id": 1,
    "method": "initialize",
    "params": {"protocolVersion": "2025-06-18", "capabilities": {}, "clientInfo": {"name": "t", "version": "1"}},
}
HEADERS = {"accept": "application/json, text/event-stream", "content-type": "application/json"}


def test_settings_include_extra_hosts():
    s = mcp_transport_security("pob2.tail1234.ts.net, other.lan")
    assert "pob2.tail1234.ts.net" in s.allowed_hosts and "other.lan:*" in s.allowed_hosts
    assert "https://pob2.tail1234.ts.net" in s.allowed_origins
    assert "localhost:*" in s.allowed_hosts


@pytest.mark.parametrize(
    ("allowed", "host", "ok"),
    [
        ("", "localhost:8080", True),
        ("", "pob2.tail1234.ts.net", False),
        ("pob2.tail1234.ts.net", "pob2.tail1234.ts.net", True),
    ],
)
def test_mcp_host_check(monkeypatch, allowed, host, ok):
    monkeypatch.setenv("POB2_ALLOWED_HOSTS", allowed)
    with TestClient(create_app(), base_url=f"http://{host}") as client:
        r = client.post("/mcp", json=INIT, headers=HEADERS)
    assert (r.status_code == 200) is ok, r.text
