# PoB-Enhanced: headless engine, MCP server and web UI

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
docker run -d -p 8080:8080 ghcr.io/skitty4fingers/pob-enhanced:latest   # prebuilt image (published by CI)
docker compose -f compose.image.yml up -d                              # same, with Compose
docker compose -f compose.enhanced.yml up -d --build                   # build from source
docker build -f docker/enhanced.Dockerfile -t pob2-enhanced .
docker run --rm -i pob2-enhanced pob2-mcp                              # MCP over stdio
```

All of these serve http://localhost:8080 with MCP at `/mcp`. The Compose files read `POB2_PORT` (host port),
`POB2_BIND` (`127.0.0.1` by default; `0.0.0.0` to reach it from your network) and `POB2_ALLOWED_HOSTS` from the
shell or a `.env` file (see `.env.example`). `.github/workflows/publish.yml` publishes the image to GitHub Container
Registry on every push to `main` (amd64 and arm64).

On Windows without WSL or Docker, the desktop app in `runtime/` is unchanged. The headless engine needs a
native `luajit.exe` built from the pinned commit (LuaJIT's own `src\msvcbuild.bat`). Put it next to the `lua-utf8.dll` from `runtime/` and point `POB2_LUAJIT` at it.

### Tailscale (private HTTPS on your tailnet)

`compose.tailscale.yml` runs PoB behind a Tailscale sidecar. No ports are published on the host. Only devices on
your tailnet can reach it, at `https://pob2.<tailnet>.ts.net`, with a real TLS certificate from Tailscale Serve.

1. In the [admin console](https://login.tailscale.com/admin/dns) enable **MagicDNS** and **HTTPS Certificates**,
   and note the tailnet name (e.g. `tail1234.ts.net`).
2. Create an [auth key](https://login.tailscale.com/admin/settings/keys).
3. `cp .env.example .env`, then set `TS_AUTHKEY` and `TS_TAILNET`.
4. `docker compose -f compose.tailscale.yml up -d --build`

Connect agents from any tailnet device:

```bash
claude mcp add --transport http pob2 https://pob2.tail1234.ts.net/mcp
```

Notes:
- The node's state is kept in the `tailscale-state` volume, so the auth key is only needed for the first login.
  Without a key, `docker compose logs tailscale` prints a login URL.
- Every tailnet member who can reach the node shares the one active build. Use `TS_EXTRA_ARGS=--advertise-tags=tag:pob2`
  and an ACL rule to limit who can reach it.
- Funnel (public internet exposure) is explicitly disabled in `docker/tailscale/serve.json`.
- `/mcp` rejects Host headers it doesn't know (DNS-rebinding protection). The compose file sets
  `POB2_ALLOWED_HOSTS` to the tailnet name. Set it yourself for any other reverse proxy.

### Configuration

| Variable | Default | Purpose |
|---|---|---|
| `POB2_LUAJIT` | `luajit` on `PATH` | LuaJIT executable |
| `POB2_ROOT` | auto-detected | Repository root (contains `src/Launch.lua` and `engine/`) |
| `POB2_ALLOWED_HOSTS` | (none) | Extra hostnames accepted by `/mcp`, comma-separated (localhost is always allowed) |
| `POB2_TREE_ART` | `<repo>/tree-art` | Passive tree artwork served at `/tree-art` (see below) |

### Passive tree artwork

The web tree draws the game's own PoE2 node icons, frames, class and ascendancy art. These come from the DDS texture
arrays in `src/TreeData/<version>/`, converted to WebP by `scripts/build_tree_art.py` and committed in `tree-art/`
(about 22 MB) so a clone or the Docker image needs no conversion step. After a tree data update, regenerate them:

```bash
uv run --no-project --with zstandard --with texture2ddecoder --with pillow python scripts/build_tree_art.py
```

Without the artwork the tree falls back to plain circles. Tree links use the official PoE2 planner format
(`https://pathofexile2.com/game/passive-skill-tree/<code>`, version 7), including weapon-set and attribute choices.

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
| Tree | `get_passive_tree`, `search_passives`, `compare_passives`, `allocate_passives`, `deallocate_passives`, `import_tree_url`, `export_tree_url` |
| Config | `list_config`, `set_config`, `set_custom_mods` |
| Guide | `load_reference_build`, `compare_to_reference`, `reference_impact`, `apply_reference_tree` |
| Advisor | `get_advice`, `set_attribute_nodes` |
| Upgrades | `gear_advice`, `shopping_advice`, `gem_advice`, `socket_advice`, `set_gem`, `refresh_build` |
| Budget | `check_item`, `get_budget` |

Resources: `pob://build/code`, `pob://build/xml`. Prompts: `analyze_build`, `optimize_passives`, `optimize_to_reference`.

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
GET|PUT|DELETE /api/reference  {content}   PoE2 BuildPlanner .build guide to compare against
GET  /api/reference/compare?level=        passive / skill / gear gaps vs the guide
GET  /api/reference/impact?level=&limit=  full guide tree stats, next steps ranked by gain per point
POST /api/reference/apply-tree            replace the passive tree with the guide's
GET  /api/advisor?metric=balanced|dps|ehp next point, point to move, attribute node advice
POST /api/tree/attributes   {changes}     set +5 Str/Dex/Int on attribute nodes
GET  /api/gear/slots | /api/gear/slot?slot=&metric=&league=   item/mod worth, what to look for, trade URL
GET  /api/gear/uniques?metric=&league=&maxPrice=          uniques ranked per slot, poe.ninja prices
GET  /api/gems/advice?metric=               support worth, swaps, level/quality upgrades, problems
GET  /api/sockets?metric=&slot=&limit=     rune/soul core/idol worth and best legal replacements per socket
GET  /api/sockets/plan?metric=&maxSwaps=   combined socket swap plan (greedy, re-measured; nothing is changed)
POST /api/skills/{group}/gems/{index}       {name?, level?, quality?, enabled?}
GET  /api/build/source  POST /api/build/refresh   re-import from the source link, keeping config
GET  /api/budget                            Spirit used/free, totems affordable vs cap, DPS across all totems
POST /api/items/check   {text, slot?}       check before you buy: verdict, every skill, Spirit/totems, warnings
GET  /api/revision              increments whenever the build changes
```

## Reference guides (.build)

The **Guide** tab (and the `*_reference*` MCP tools) compare the live build with a build guide exported as a PoE2
BuildPlanner `.build` file (the format the in-game planner and Maxroll use). Import your character first, then upload
the guide. You get:

- passives the guide takes that you don't, and yours it doesn't, with weapon-set and ascendancy checks
- skill gems and supports (tiers like "Biting Frost I/II" count as the same support), and the guide's gear and notes
- the stat change from respeccing to the guide's whole tree, the guide's notables ranked by DPS% + EHP% per point
  (each with the path through guide nodes, one click to allocate), and what each of your extra notables is worth

Guides are staged by character level (`level_interval`); the comparison uses your build's level unless you pick a
stage. The reference is kept in memory until replaced or the server restarts.

## Advisor

The Tree tab's **Advisor** panel (and `get_advice`) answers three questions, measured with PoB's calculator:

- **Next point** (green, `NEXT`): the first node toward the best target by gain per point. With a guide loaded it
  follows the guide's nodes; otherwise it searches notables within 8 points. Optimise for balanced, damage or defence.
- **Move a point** (red, `MOVE`): the allocated end-of-branch node that is cheapest to refund (never disconnects
  anything), with the gain from spending it on the next point. With a guide, only nodes the guide doesn't take.
- **Attribute nodes** (amber, `→ Int`): recommended vs current +5 choice for every attribute node. Each swap is
  measured, and gear/gem attribute requirements are respected (shortfalls are fixed first, surpluses spent on gain).
  Hover a node for the reason; apply one or all.

## Spirit, totems and "check before you buy"

PoB reports a totem skill's DPS **per totem**, reserves Ancestral Bond's "75 Spirit per totem" only once, and does not
parse "Your Totem Limit is doubled". On its own it therefore can't show that a weapon with less Spirit costs totems.
PoB2-Enhanced adds a Spirit/totem budget on top of PoB's outputs (`engine/pobapi/api/budget.lua`):

- totem cap = PoB's limit, doubled for Ancestral Bond while PoB doesn't apply it (detected at runtime)
- totems kept up = min(cap, Spirit available ÷ Spirit per totem), or the Config tab's "# of Summoned Totems"
- **DPS, all totems** = per-totem DPS × totems kept up. Every advisor (tree, gear, shop, gems, guide) scores with it,
  so anything that costs totems or Spirit shows up as lost damage, with `totemsDelta` / `spiritDelta` on each row
- what-ifs that replace an item also drop the skills that item granted (e.g. Sacred Flame's Purity of Fire)

The sidebar shows Spirit in use, what reserves it, totems and the Spirit needed for the next one. **Check item**
(Upgrades tab, Items tab, `check_item`) gives an upgrade/sidegrade/downgrade verdict with warnings for lost totems,
Spirit shortfalls, attribute requirements and removed skills, and each damage skill measured separately. The Items
tab asks for confirmation before equipping an item that has warnings.

## Upgrades tab

Everything is measured in your build by PoB (Balanced = DPS% + EHP%, or Damage / Defence only):

- **Gear / Jewels**: per slot, what the item and each mod is worth (dead mods flagged; mods holding up an attribute
  requirement are marked as needed), what to look for on a replacement (PoB's trade stat weighting at average rolls),
  the headroom a good replacement would add, and a weighted pathofexile.com trade search. Empty slots are evaluated
  with an endgame base (a focus behind a one-handed caster weapon, a quiver behind a bow, otherwise a shield).
- **Gems**: what each support is worth (secondary damage skills on their own DPS, utility skills on the build), the
  best replacement for the weakest support per skill (regular, plus the best lineage support), gem level/quality
  upgrades, and problems (disabled, duplicate, harmful supports). One click applies a suggestion.
- **Shop**: every unique in PoB's database that fits a slot, measured in your build, with poe.ninja prices for the
  chosen league, a budget filter, best gain per divine, and trade links.

Import a **poe.ninja character page** (`https://poe.ninja/poe2/builds/<league>/character/<account>/<name>`) or any
build link and the header's **Update** button re-imports it later, keeping your Config tab settings.

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
