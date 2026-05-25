"""Spawn and talk to the Path of Building engine bridge.

Two modes, selected automatically at startup:

GUI mode  — PoB GUI is running with pob-mcp/gui_bridge.lua loaded.
            The client connects to a TCP socket on 127.0.0.1:12321 and
            operates on the live build object inside the GUI process.
            Changes (allocate nodes, config tweaks) are visible in the GUI
            immediately without saving/reloading XML.

Headless mode — No GUI. Spawns a separate LuaJIT subprocess running
            pob-mcp/engine/bridge.lua. Identical JSON-line protocol over
            stdin/stdout. Falls back here when the GUI is not running.

The selection is transparent to server.py — both modes implement the same
request() / load_xml() API.
"""

from __future__ import annotations

import json
import os
import shutil
import socket as _socket
import subprocess
import sys
import threading
import time
from pathlib import Path
from typing import Any, Optional

REPO_ROOT = Path(__file__).resolve().parents[2]
SRC_DIR = REPO_ROOT / "src"
RUNTIME_DIR = REPO_ROOT / "runtime"
BRIDGE_LUA = REPO_ROOT / "pob-mcp" / "engine" / "bridge.lua"

GUI_HOST = "127.0.0.1"
GUI_PORT = 12321
GUI_CONNECT_TIMEOUT = 0.3   # seconds to wait when probing for GUI
GUI_LOAD_WAIT = 0.7         # seconds to wait after load_xml in GUI mode


class EngineError(RuntimeError):
    pass


# ---------------------------------------------------------------------------
# Runtime detection helpers (headless mode only)
# ---------------------------------------------------------------------------

def _find_luajit() -> Optional[str]:
    env = os.environ.get("POB_LUAJIT")
    if env and Path(env).exists():
        return env
    found = shutil.which("luajit")
    if found:
        return found
    local = os.environ.get("LOCALAPPDATA")
    if local:
        cand = Path(local) / "Programs" / "LuaJIT" / "bin" / "luajit.exe"
        if cand.exists():
            return str(cand)
    return None


def _build_launch() -> tuple[list[str], dict[str, str], str]:
    runtime = os.environ.get("POB_RUNTIME", "").lower()
    lua_path = f"{RUNTIME_DIR}/lua/?.lua;{RUNTIME_DIR}/lua/?/init.lua;;"
    lua_cpath = f"{RUNTIME_DIR}/?.dll;{RUNTIME_DIR}/?.so;;"

    if runtime == "docker":
        image = os.environ.get(
            "POB_DOCKER_IMAGE",
            "ghcr.io/pathofbuildingcommunity/pathofbuilding-tests:latest",
        )
        argv = [
            "docker", "run", "--rm", "-i",
            "-v", f"{REPO_ROOT}:/workdir:ro",
            "-w", "/workdir/src",
            "-e", "LUA_PATH=../runtime/lua/?.lua;../runtime/lua/?/init.lua;;",
            "-e", "LUA_CPATH=../runtime/?.so;;",
            image,
            "luajit", "/workdir/pob-mcp/engine/bridge.lua",
        ]
        return argv, dict(os.environ), str(REPO_ROOT)

    luajit = _find_luajit()
    if not luajit:
        raise EngineError(
            "LuaJIT not found. Install it (winget install DEVCOM.LuaJIT), set "
            "POB_LUAJIT to luajit.exe, or set POB_RUNTIME=docker."
        )
    env = dict(os.environ)
    env["LUA_PATH"] = lua_path
    env["LUA_CPATH"] = lua_cpath
    argv = [luajit, str(BRIDGE_LUA)]
    return argv, env, str(SRC_DIR)


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
    if os.environ.get("POB_RUNTIME", "").lower() in ("headless", "docker"):
        return None  # user explicitly wants headless
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
        sock.close()
        return None
    except Exception:
        return None


# ---------------------------------------------------------------------------
# Public client — auto-selects GUI vs headless
# ---------------------------------------------------------------------------

class EngineClient:
    """Engine client with automatic GUI / headless mode selection.

    On every request the client first checks if the PoB GUI bridge is
    reachable (127.0.0.1:12321). If yes it uses that connection (live mode).
    If not it falls back to the headless LuaJIT subprocess.
    """

    def __init__(self) -> None:
        self._gui: Optional[_GUITransport] = None
        self._proc: Optional[subprocess.Popen] = None
        self._lock = threading.Lock()
        self._next_id = 0
        self._last_xml: Optional[str] = None
        self._stderr_thread: Optional[threading.Thread] = None

    # -- GUI mode -----------------------------------------------------------

    def _ensure_gui(self) -> bool:
        """Try (re)connecting to the GUI bridge. Returns True if connected."""
        if self._gui is not None:
            # Quick liveness check
            try:
                self._gui._sock.settimeout(0.05)
                data = self._gui._sock.recv(1, _socket.MSG_PEEK)
                if data == b"":
                    raise OSError("closed")
            except (_socket.timeout, BlockingIOError):
                pass  # no data but still alive
            except OSError:
                self._gui.close()
                self._gui = None
        if self._gui is None:
            self._gui = _try_connect_gui()
        return self._gui is not None

    # -- Headless mode ------------------------------------------------------

    def _alive(self) -> bool:
        return self._proc is not None and self._proc.poll() is None

    def _drain_stderr(self, proc: subprocess.Popen) -> None:
        assert proc.stderr is not None
        for line in proc.stderr:
            sys.stderr.write(f"[pob-engine] {line.rstrip()}\n")
            sys.stderr.flush()

    def start(self) -> None:
        if self._alive():
            return
        argv, env, cwd = _build_launch()
        self._proc = subprocess.Popen(
            argv, cwd=cwd, env=env,
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            text=True, encoding="utf-8", bufsize=1,
        )
        self._stderr_thread = threading.Thread(
            target=self._drain_stderr, args=(self._proc,), daemon=True
        )
        self._stderr_thread.start()
        self._read_until_ready()

    def _read_until_ready(self) -> None:
        assert self._proc and self._proc.stdout
        for _ in range(200):
            line = self._proc.stdout.readline()
            if not line:
                raise EngineError("engine exited before becoming ready")
            line = line.strip()
            if not line:
                continue
            try:
                msg = json.loads(line)
            except json.JSONDecodeError:
                continue
            if msg.get("event") == "ready":
                return
        raise EngineError("engine did not emit ready event")

    def stop(self) -> None:
        if self._proc:
            try:
                self._proc.terminate()
            except Exception:
                pass
            self._proc = None
        if self._gui:
            self._gui.close()
            self._gui = None

    def _raw_request(self, cmd: str, **args: Any) -> Any:
        assert self._proc and self._proc.stdin and self._proc.stdout
        self._next_id += 1
        req_id = self._next_id
        payload = {"id": req_id, "cmd": cmd, **args}
        self._proc.stdin.write(json.dumps(payload) + "\n")
        self._proc.stdin.flush()
        while True:
            line = self._proc.stdout.readline()
            if not line:
                raise EngineError(f"engine closed stdout while waiting for '{cmd}'")
            line = line.strip()
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
                raise EngineError(msg.get("error", "unknown engine error"))
            return msg.get("result")

    def _replay(self) -> None:
        if self._last_xml:
            self._raw_request("load_xml", xml=self._last_xml, name="MCP build")

    # -- unified API --------------------------------------------------------

    def request(self, cmd: str, **args: Any) -> Any:
        """Send a command, auto-selecting GUI or headless transport."""
        with self._lock:
            # Prefer GUI mode when available
            if self._ensure_gui():
                try:
                    return self._gui.request(cmd, **args)  # type: ignore[union-attr]
                except EngineError:
                    raise
                except Exception as exc:
                    # Connection dropped; clear and fall through to headless
                    sys.stderr.write(f"[pob-mcp] GUI connection lost: {exc}; falling back to headless\n")
                    sys.stderr.flush()
                    if self._gui:
                        self._gui.close()
                        self._gui = None

            # Headless fallback
            if not self._alive():
                self.start()
                self._replay()
            try:
                return self._raw_request(cmd, **args)
            except EngineError:
                self.stop()
                self.start()
                self._replay()
                return self._raw_request(cmd, **args)

    def load_xml(self, xml: str, name: str = "MCP build") -> Any:
        """Load build XML. In GUI mode, triggers PoB's own loader and waits."""
        with self._lock:
            if self._ensure_gui():
                try:
                    result = self._gui.request("load_xml", xml=xml, name=name)  # type: ignore[union-attr]
                    if result and result.get("pending"):
                        # PoB's SetMode is async; wait for the next OnFrame to apply it
                        time.sleep(GUI_LOAD_WAIT)
                    return result
                except Exception as exc:
                    sys.stderr.write(f"[pob-mcp] GUI load failed: {exc}; falling back to headless\n")
                    sys.stderr.flush()
                    if self._gui:
                        self._gui.close()
                        self._gui = None

            # Headless
            if not self._alive():
                self.start()
            result = self._raw_request("load_xml", xml=xml, name=name)
            self._last_xml = xml
            return result

    @property
    def is_gui_mode(self) -> bool:
        """True when connected to the PoB GUI bridge."""
        return self._gui is not None
