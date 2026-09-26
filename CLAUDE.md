# PoB2-Enhanced

A fork of Path of Building 2 (PoE2 build planner, Lua) that adds a headless engine, an MCP server, a REST API and a web UI.
Full docs: `docs/enhanced.md`.

## Layout
- `src/`, `runtime/`, `spec/`: upstream PoB. **Do not edit.** Keep the fork rebasable on upstream `dev`.
  Upstream Lua uses LuaJIT 2026 syntax extensions (`+=`, `..=`, `continue`, `|x| -> expr`). These are valid; do not "fix" them.
- `engine/`: headless worker. `worker.lua` handles JSON-lines RPC over stdio. Handlers are in `engine/pobapi/api/<ns>.lua`
  and auto-register as `<ns>.<fn>`. Must run with cwd=`src/`.
- `python/`: `pob2` package (uv). `engine.py` manages the process, `service.py` holds shared operations,
  `mcp_server.py` (MCP SDK v2 `MCPServer`), `web/` (FastAPI) and `cli.py`.
- `web/`: React 19 + Vite + Tailwind 4 + TanStack Query. Builds into `python/src/pob2/web/static`.

## Commands
- Runtime: `scripts/setup-engine.sh` (LuaJIT at commit 2460b3ff + lua-utf8 into ~/.local)
- Python: `cd python && uv run pytest && uv run ruff check src tests && uv run ruff format src tests`
- Web: `cd web && npm run build` (runs a typecheck first)
- Run: `uv run --directory python pob2-web` (UI + REST + MCP at /mcp) or `pob2-mcp` (stdio)
- Worker smoke test: `cd src && echo '{"id":1,"method":"worker.ping"}' | luajit ../engine/worker.lua`

## Conventions
- Lua: tabs, match upstream style. Return plain tables. Use `util.array()` for lists that may be empty,
  `util.fail()` for user errors, and `session.recalc()` after changes.
- New build-changing worker methods must be added to `MUTATING` in `service.py` (drives UI live refresh).
- Python: ruff, line length 120, type hints. Keep MCP tool docstrings short and agent-oriented.
