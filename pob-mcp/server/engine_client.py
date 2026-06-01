"""Client for the Path of Building GUI bridge.

Connects to the TCP bridge (pob-mcp/gui_bridge.lua) that runs inside the
PoB GUI process on 127.0.0.1:12321.  All commands operate on the live build
object — changes are visible in the GUI immediately.

If PoB is not running, every command fails with a clear EngineError.
The connection is established lazily and re-established automatically
after PoB is restarted.
"""

from __future__ import annotations

import json
import socket as _socket
import sys
import threading
import time
from typing import Any, Optional

GUI_HOST = "127.0.0.1"
GUI_PORT = 12321
GUI_CONNECT_TIMEOUT = 1.5   # seconds to wait when probing for GUI
GUI_LOAD_WAIT = 0.7         # seconds to wait after load_xml in GUI mode


class EngineError(RuntimeError):
    pass


# ---------------------------------------------------------------------------
# GUI mode — TCP socket transport
# ---------------------------------------------------------------------------

class _GUITransport:
    """Thin wrapper around a TCP socket to the PoB GUI bridge."""

    def __init__(self, sock: _socket.socket) -> None:
        self._sock = sock
        self._buf = b""
        self._next_id = 0
        self._lock = threading.Lock()

    def _read_line(self, timeout: float = 30.0) -> str:
        self._sock.settimeout(timeout)
        deadline = time.monotonic() + timeout
        while b"\n" not in self._buf:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise EngineError("GUI bridge: timeout waiting for response")
            self._sock.settimeout(remaining)
            chunk = self._sock.recv(4096)
            if not chunk:
                raise EngineError("GUI bridge: connection closed")
            self._buf += chunk
        nl = self._buf.index(b"\n")
        line = self._buf[:nl].decode("utf-8")
        self._buf = self._buf[nl + 1:]
        return line

    def request(self, cmd: str, **args: Any) -> Any:
        with self._lock:
            self._next_id += 1
            req_id = self._next_id
            payload = json.dumps({"id": req_id, "cmd": cmd, **args}) + "\n"
            self._sock.sendall(payload.encode("utf-8"))
            while True:
                line = self._read_line()
                if not line:
                    continue
                try:
                    msg = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if msg.get("event"):
                    continue
                if msg.get("id") != req_id:
                    continue
                if not msg.get("ok"):
                    raise EngineError(msg.get("error", "unknown GUI bridge error"))
                return msg.get("result")

    def close(self) -> None:
        try:
            self._sock.close()
        except Exception:
            pass


def _try_connect_gui() -> Optional[_GUITransport]:
    """Try to connect to a running PoB GUI bridge. Returns None if not available."""
    sock = None
    try:
        sock = _socket.socket(_socket.AF_INET, _socket.SOCK_STREAM)
        sock.settimeout(GUI_CONNECT_TIMEOUT)
        sock.connect((GUI_HOST, GUI_PORT))
        sock.settimeout(5.0)
        transport = _GUITransport(sock)
        # Read the ready handshake the bridge sends on connect
        line = transport._read_line(timeout=3.0)
        msg = json.loads(line)
        if msg.get("event") == "ready" and msg.get("gui"):
            sys.stderr.write("[pob-mcp] Connected to PoB GUI bridge (live mode)\n")
            sys.stderr.flush()
            return transport
        if sock:
            sock.close()
        return None
    except Exception as _e:
        sys.stderr.write(f"[pob-mcp] _try_connect_gui failed: {_e!r}\n")
        sys.stderr.flush()
        if sock:
            try:
                sock.close()
            except Exception:
                pass
        return None


# ---------------------------------------------------------------------------
# Public client
# ---------------------------------------------------------------------------

_NOT_RUNNING_MSG = (
    "Path of Building is not running or the GUI bridge is not ready. "
    "Start PoB, wait for it to fully load, then retry."
)


class EngineClient:
    """Engine client — GUI-only mode.

    Every request goes to the live PoB GUI bridge on 127.0.0.1:12321.
    If PoB is not running, commands fail immediately with a clear error.
    The connection is established lazily and re-established automatically
    after PoB restarts (each request retries the connection if it was lost).
    """

    def __init__(self) -> None:
        self._gui: Optional[_GUITransport] = None
        self._lock = threading.Lock()

    def _ensure_gui(self) -> _GUITransport:
        """Return a live GUI transport, or raise EngineError if PoB is not running."""
        # Liveness check on existing connection
        if self._gui is not None:
            try:
                self._gui._sock.settimeout(0.05)
                data = self._gui._sock.recv(1, _socket.MSG_PEEK)
                if data == b"":
                    raise OSError("closed")
            except (_socket.timeout, BlockingIOError):
                pass  # socket alive but no data pending
            except OSError:
                self._gui.close()
                self._gui = None

        # Try (re)connecting
        if self._gui is None:
            self._gui = _try_connect_gui()

        if self._gui is None:
            raise EngineError(_NOT_RUNNING_MSG)

        return self._gui

    def _drop_gui(self) -> None:
        if self._gui:
            self._gui.close()
            self._gui = None

    # -- public API ---------------------------------------------------------

    def request(self, cmd: str, **args: Any) -> Any:
        """Send a command to the PoB GUI bridge."""
        with self._lock:
            transport = self._ensure_gui()
            try:
                return transport.request(cmd, **args)
            except Exception as exc:
                sys.stderr.write(f"[pob-mcp] GUI request failed: {exc}\n")
                sys.stderr.flush()
                self._drop_gui()
                if isinstance(exc, EngineError):
                    raise
                raise EngineError(f"GUI connection lost: {exc}") from exc

    def load_xml(self, xml: str, name: str = "MCP build") -> Any:
        """Load build XML into the PoB GUI."""
        with self._lock:
            transport = self._ensure_gui()
            try:
                result = transport.request("load_xml", xml=xml, name=name)
                if result and result.get("pending"):
                    time.sleep(GUI_LOAD_WAIT)
                return result
            except Exception as exc:
                sys.stderr.write(f"[pob-mcp] GUI load failed: {exc}\n")
                sys.stderr.flush()
                self._drop_gui()
                if isinstance(exc, EngineError):
                    raise
                raise EngineError(f"GUI load failed: {exc}") from exc

    @property
    def is_gui_mode(self) -> bool:
        return self._gui is not None
