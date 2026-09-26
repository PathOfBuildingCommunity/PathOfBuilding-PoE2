# PoB2-Enhanced: headless engine, MCP server and web UI

PoB2-Enhanced runs the unmodified Path of Building 2 calculation engine without the Windows desktop UI. It adds:

| Layer | Path | What it is |
|---|---|---|
| Engine worker | `engine/` | LuaJIT process that boots PoB headless and answers JSON-RPC on stdin/stdout |
| Python bridge | `python/src/pob2/` | Process manager, share-code codec, and a service layer shared by everything below |
| MCP server | `pob2-mcp` | 30+ tools that let AI agents (Claude, etc.) load, inspect, what-if and edit builds |
| REST API + web UI | `pob2-web`, `web/` | FastAPI + React UI (tree, skills, items, config). Also serves MCP at `/mcp` |
| CLI | `pob2` | JSON output for scripting (`jq`, PowerShell `ConvertFrom-Json`) |

Nothing under `src/` is modified, so upstream updates merge cleanly.

```
 AI agent ──MCP (stdio or /mcp)──┐
 Browser ──REST /api ────────────┼─► PoBService ─► Engine ─► luajit engine/worker.lua ─► src/ (PoB)
 Scripts ──pob2 CLI ─────────────┘   (python)      (process, JSON lines)
```

When the web UI and an agent use the same `pob2-web` process, they share one live build. The UI polls
`/api/revision` and refreshes as the agent makes changes.

## Requirements

- **LuaJIT from commit `2460b3ff` (2026-07-20) or newer.** PoB now uses LuaJIT's syntax extensions (`+=`, `..=`,
  `continue`, `|x| -> expr`). Distro packages are older and fail with `'=' expected near '+'`.
- The `lua-utf8` C module.
- Python 3.10+ and [uv](https://docs.astral.sh/uv/).
- Node 22+ (only to build the web UI).

## Setup

### Linux / macOS / WSL

```bash
scripts/setup-engine.sh          # builds LuaJIT + lua-utf8 into ~/.local, runs uv sync, builds the web UI
export PATH="$HOME/.local/bin:$PATH"
uv run --directory python pob2-web   # http://127.0.0.1:8080
```

### Docker (any OS, including Windows)

```bash
docker compose -f compose.enhanced.yml up --build        # http://localhost:8080, MCP at http://localhost:8080/mcp
docker build -f docker/enhanced.Dockerfile -t pob2-enhanced .
docker run --rm -i pob2-enhanced pob2-mcp                 # MCP over stdio
```

On Windows without WSL or Docker, the desktop app in `runtime/` is unchanged. The headless engine needs a
native `luajit.exe` built from the pinned commit (LuaJIT's own `src\msvcbuild.bat`). Put it next to the `lua-utf8.dll` from `runtime/` and point `POB2_LUAJIT` at it.

### Configuration

| Variable | Default | Purpose |
|---|---|---|
| `POB2_LUAJIT` | `luajit` on `PATH` | LuaJIT executable |
| `POB2_ROOT` | auto-detected | Repository root (contains `src/Launch.lua` and `engine/`) |

## Connecting AI agents (MCP)

**Claude Code:** this repo ships `.mcp.json`, so Claude Code offers the `pob2` server automatically in the repo.
Elsewhere:

```bash
claude mcp add pob2 -- uv run --directory /path/to/PoB2-Enhanced/python pob2-mcp
claude mcp add --transport http pob2 http://127.0.0.1:8080/mcp     # share the web UI's live build
```

**Claude Desktop** (`claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "pob2": { "command": "uv", "args": ["run", "--directory", "C:/path/to/PoB2-Enhanced/python", "pob2-mcp"] }
  }
}
```

or with Docker: `"command": "docker", "args": ["run", "--rm", "-i", "pob2-enhanced", "pob2-mcp"]`.

`pob2-mcp --http --port 8765` serves streamable HTTP without the web UI.

### Tools

| Area | Tools |
|---|---|
| Build | `load_build`, `new_build`, `get_build_overview`, `export_build`, `set_character`, `list_classes` |
| Stats | `get_stats`, `get_stat_summary` |
| Skills | `list_skills`, `add_skill_group`, `set_main_skill`, `set_skill_group_enabled`, `remove_skill_group`, `search_gems` |
| Items | `list_items`, `list_item_slots`, `compare_item`, `equip_item`, `unequip_item`, `parse_item`, `search_uniques`, `get_unique`, `search_item_bases` |
| Tree | `get_passive_tree`, `search_passives`, `compare_passives`, `allocate_passives`, `deallocate_passives`, `import_tree_url` |
| Config | `list_config`, `set_config`, `set_custom_mods` |

Resources: `pob://build/code`, `pob://build/xml`. Prompts: `analyze_build`, `optimize_passives`.

The `compare_*` tools run PoB's own what-if calculator, the same one behind the desktop tooltips, and never
change the build. This lets an agent measure a change before applying it.

## REST API

`pob2-web` serves an OpenAPI reference at `/docs`. Main routes:

```
GET  /api/build                 overview (info, stats, skills, items, non-default config)
POST /api/build/import          {source}  share code | pobb.in/pastebin/poe.ninja link | XML
POST /api/build/new             {className, ascendancy, level}
GET  /api/build/export          {code, xml}
GET  /api/stats?keys=TotalDPS   raw output
GET  /api/skills   POST /api/skills   POST /api/skills/{n}/main   PATCH|DELETE /api/skills/{n}
GET  /api/items    POST /api/items/equip|compare|parse   DELETE /api/items/{slot}
GET  /api/tree     GET /api/tree/layout|search|node/{id}   POST /api/tree/allocate|deallocate|compare|reset
GET  /api/config   PATCH /api/config {values}   GET|PUT /api/config/custom-mods
GET  /api/data/gems|uniques|uniques/{name}|bases
GET  /api/revision              increments whenever the build changes
```

## CLI

```bash
pob2 overview -b <code|link|build.xml>
pob2 stats -b build.xml --keys TotalDPS Life
pob2 call tree.search '{"query": "spell damage"}' -b <code>
pob2 decode <code> > build.xml ; pob2 encode build.xml
pob2 methods
```

```powershell
uv run --directory python pob2 stats -b $code --keys TotalDPS | ConvertFrom-Json
```

## Worker protocol

`luajit ../engine/worker.lua`, run with the working directory set to `src/`:

```
← {"event":"ready","methods":[...]}
→ {"id":1,"method":"tree.search","params":{"query":"spell damage"}}
← {"id":1,"result":[...]}            or  {"id":1,"error":{"message":"...","code":"bad_request"}}
```

PoB's console output goes to stderr. Error codes: `bad_request`, `not_found`, `method_not_found`, `internal`.

### Adding a method

1. Add a function to the right module in `engine/pobapi/api/` (`build`, `stats`, `skills`, `items`, `tree`,
   `config`, `data`). It is registered automatically as `<module>.<function>`. Use `util.fail(msg)` for user
   errors and `session.recalc()` after changing the build.
2. If it changes the build, add it to `MUTATING` in `python/src/pob2/service.py`.
3. Expose it as an MCP tool in `mcp_server.py` and/or a route in `web/routes.py`.
4. Add a test in `python/tests/test_engine.py`.

## Development

```bash
cd python && uv run pytest && uv run ruff check src tests && uv run ruff format src tests
cd web && npm run dev          # Vite on :5173, proxies /api and /mcp to pob2-web on :8080
uv run --directory python pob2-web --reload
```

Upstream PoB tests (busted) still run through `docker compose up` as described in `CONTRIBUTING.md`.
