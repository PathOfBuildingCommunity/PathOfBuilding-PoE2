"""Boot the engine and exercise the core analysis path. No real build required."""

from __future__ import annotations

import sys

from engine_client import EngineClient


def main() -> int:
    engine = EngineClient()
    try:
        assert engine.request("ping") == "pong"
        print("ping OK")
        print("new_build:", engine.request("new_build"))
        print("summary:", engine.request("list_state", what="summary"))
        ranked = engine.request("rank_nodes", metric="Evasion", maxDepth=2, limit=3)
        print("rank Evasion:", ranked)
        assert ranked["withEffect"] >= 1, "expected at least one evasion node"
        print("\nSMOKE TEST PASSED")
        return 0
    finally:
        engine.stop()


if __name__ == "__main__":
    sys.exit(main())
