"""Manages the LuaJIT headless worker process (engine/worker.lua) and its JSON-lines protocol."""

from __future__ import annotations

import itertools
import json
import logging
import os
import queue
import shutil
import subprocess
import threading
from collections import deque
from pathlib import Path
from typing import Any

log = logging.getLogger("pob2.engine")

DEFAULT_START_TIMEOUT = 120.0
DEFAULT_CALL_TIMEOUT = 120.0


class EngineError(RuntimeError):
    """Error reported by the worker, or a failure to talk to it."""

    def __init__(self, message: str, code: str = "internal", traceback: str | None = None):
        super().__init__(message)
        self.code = code
        self.traceback = traceback


def find_repo_root(start: Path | None = None) -> Path:
    """Locate the repository root (the directory containing src/Launch.lua and engine/)."""
    env = os.environ.get("POB2_ROOT")
    candidates = [Path(env)] if env else []
    for base in (start, Path(__file__).resolve(), Path.cwd()):
        if base:
            candidates.extend([base, *base.parents])
    for path in candidates:
        if (path / "src" / "Launch.lua").is_file() and (path / "engine" / "worker.lua").is_file():
            return path
    raise EngineError("Could not find the PoB2-Enhanced repository. Set POB2_ROOT to the repo root.", "config")


def find_luajit() -> str:
    exe = os.environ.get("POB2_LUAJIT") or shutil.which("luajit")
    if not exe:
        raise EngineError(
            "LuaJIT not found. Run scripts/setup-engine.sh (or set POB2_LUAJIT). "
            "PoB needs LuaJIT built from commit 2460b3ff (2026-07-20) or newer.",
            "config",
        )
    return exe


class Engine:
    """A single PoB build session backed by one worker process. Thread-safe; calls are serialised."""

    def __init__(
        self,
        root: Path | None = None,
        luajit: str | None = None,
        start_timeout: float = DEFAULT_START_TIMEOUT,
        call_timeout: float = DEFAULT_CALL_TIMEOUT,
    ):
        self.root = root or find_repo_root()
        self.luajit = luajit or find_luajit()
        self.start_timeout = start_timeout
        self.call_timeout = call_timeout
        self.methods: list[str] = []
        self._proc: subprocess.Popen[str] | None = None
        self._lines: queue.Queue[str | None] = queue.Queue()
        self._stderr: deque[str] = deque(maxlen=200)
        self._ids = itertools.count(1)
        self._lock = threading.RLock()

    # -- lifecycle -------------------------------------------------------------------------------

    @property
    def running(self) -> bool:
        return self._proc is not None and self._proc.poll() is None

    def start(self) -> None:
        with self._lock:
            if self.running:
                return
            self._lines = queue.Queue()
            env = {**os.environ, "CI": ""}
            self._proc = subprocess.Popen(
                [self.luajit, str(self.root / "engine" / "worker.lua")],
                cwd=self.root / "src",
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                encoding="utf-8",
                bufsize=1,
                env=env,
            )
            threading.Thread(target=self._pump, args=(self._proc.stdout, self._lines.put), daemon=True).start()
            threading.Thread(target=self._pump, args=(self._proc.stderr, self._log_stderr), daemon=True).start()
            msg = self._read(self.start_timeout, "starting")
            if msg.get("event") != "ready":
                err = msg.get("error", {}).get("message", msg)
                self.stop()
                raise EngineError(f"Worker failed to start: {err}{self._stderr_tail()}", "startup")
            self.methods = msg.get("methods", [])
            log.info("PoB worker ready (%d methods)", len(self.methods))

    def stop(self) -> None:
        with self._lock:
            proc, self._proc = self._proc, None
            if not proc:
                return
            try:
                if proc.poll() is None and proc.stdin:
                    proc.stdin.write(json.dumps({"id": 0, "method": "worker.shutdown"}) + "\n")
                    proc.stdin.flush()
                    proc.wait(timeout=5)
            except (OSError, subprocess.TimeoutExpired):
                proc.kill()

    def restart(self) -> None:
        self.stop()
        self.start()

    def __enter__(self) -> Engine:
        self.start()
        return self

    def __exit__(self, *exc: object) -> None:
        self.stop()

    # -- calls -----------------------------------------------------------------------------------

    def call(self, method: str, params: dict[str, Any] | None = None, timeout: float | None = None) -> Any:
        with self._lock:
            if not self.running:
                self.start()
            assert self._proc and self._proc.stdin
            req_id = next(self._ids)
            payload = {"id": req_id, "method": method, "params": params or {}}
            try:
                self._proc.stdin.write(json.dumps(payload) + "\n")
                self._proc.stdin.flush()
            except OSError as exc:
                self.stop()
                raise EngineError(f"Worker pipe closed: {exc}{self._stderr_tail()}", "crashed") from exc
            while True:
                msg = self._read(timeout or self.call_timeout, method)
                if msg.get("id") == req_id:
                    break
            if "error" in msg:
                err = msg["error"] or {}
                raise EngineError(
                    err.get("message", "Unknown error"), err.get("code", "internal"), err.get("traceback")
                )
            return msg.get("result")

    # -- internals -------------------------------------------------------------------------------

    def _read(self, timeout: float, context: str) -> dict[str, Any]:
        try:
            line = self._lines.get(timeout=timeout)
        except queue.Empty:
            self.stop()
            raise EngineError(f"Worker timed out ({context}) after {timeout:.0f}s", "timeout") from None
        if line is None:
            self._proc = None
            raise EngineError(f"Worker exited unexpectedly ({context}).{self._stderr_tail()}", "crashed")
        try:
            return json.loads(line)
        except json.JSONDecodeError:
            log.warning("Non-JSON worker output: %s", line.rstrip())
            return self._read(timeout, context)

    @staticmethod
    def _pump(stream: Any, sink: Any) -> None:
        for line in stream:
            sink(line)
        sink(None)

    def _log_stderr(self, line: str | None) -> None:
        if line is not None:
            self._stderr.append(line.rstrip())
            log.debug("lua: %s", line.rstrip())

    def _stderr_tail(self) -> str:
        tail = "\n".join(list(self._stderr)[-15:])
        return f"\n--- worker stderr ---\n{tail}" if tail else ""
