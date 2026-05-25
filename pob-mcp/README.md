# pob-mcp — MCP server for Path of Building (PoE2)

Lets AI agents **analyze and tune builds** through the headless Path of Building
calculation engine: read computed stats, rank passive-tree nodes by marginal value,
and run what-if comparisons — without opening the PoB GUI.

## Two operating modes

### Live mode (PoB GUI running) — recommended

```
agent ──MCP(stdio)──▶ server/server.py ──TCP 127.0.0.1:12321──▶ gui_bridge.lua
                                                                   └─ runs inside PoB GUI process
                                                                      same build object as the GUI
```

When the PoB GUI is open, the MCP server connects to a tiny TCP bridge that runs
**inside the PoB process**. Every `allocate_nodes` or `set_config` call updates the
live `build` object immediately — you see the change in the PoB window before the
agent's response arrives.

Requires a one-time ~5-line edit to `src/Launch.lua` (already applied in this repo).

### Headless mode (fallback)

```
agent ──MCP(stdio)──▶ server/server.py ──JSON lines──▶ engine/bridge.lua (LuaJIT)
                                                         └─ loads src/HeadlessWrapper.lua
```

Used automatically when the PoB GUI is not running. Spawns a standalone LuaJIT
subprocess. The engine is crash-tolerant and replays the last build on restart.

### Auto-detection

`server.py` probes `127.0.0.1:12321` on startup. If the GUI bridge answers → live
mode. Otherwise → headless. No configuration needed. Force headless with
`POB_RUNTIME=headless`.

## Prerequisites

1. **LuaJIT** (native, recommended):
   ```powershell
   winget install DEVCOM.LuaJIT
   ```
   Auto-detected on PATH or at `%LOCALAPPDATA%\Programs\LuaJIT\bin\luajit.exe`.
   Override with `POB_LUAJIT=C:\path\to\luajit.exe`.

   *Alternative:* set `POB_RUNTIME=docker` to run the engine inside the PoB test image
   (`ghcr.io/pathofbuildingcommunity/pathofbuilding-tests`) instead of native LuaJIT.

2. **Python 3.10+** with the MCP SDK:
   ```powershell
   pip install -r pob-mcp/requirements.txt
   ```

## Quick check

```powershell
# from the repo root
python pob-mcp/server/smoke_test.py
```

This boots the engine, creates a build, and prints a couple of analysis results.

## Connect to Claude Code

Add to your MCP config (e.g. `.mcp.json` at the repo root or your user config):

```json
{
  "mcpServers": {
    "path-of-building": {
      "command": "python",
      "args": ["pob-mcp/server/server.py"]
    }
  }
}
```

Use an absolute path to `server.py` (and to a venv `python`) if your client does not
run from the repo root.

## Tools

### Analysis (read-only)

| Tool | What it does |
|------|--------------|
| `load_build(source, name?)` | Load a build from raw XML, a PoB build code, or a `.xml` file path saved by the GUI. Call this first. |
| `get_stats(fields?)` | Full flat stat table (offence/defence/attributes/charges + `SkillDPS`), or just the requested keys. |
| `get_summary()` | Headline numbers plus sanity warnings (uncapped resists, low pool). |
| `rank_passive_nodes(metric, max_depth, limit)` | Rank unallocated nodes by gain to `metric` (FullDPS, CombinedDPS, Life, Evasion, …), with `delta` and `deltaPerPoint`. |
| `evaluate_change(add_nodes?, remove_nodes?, conditions?, metrics?, full_output?)` | What-if: deltas from adding/removing nodes, **without** mutating the build. |
| `set_config(key, value)` | Set a ConfigTab option (enemy level, charges, buffs) or `mainSocketGroup` and recalc. |
| `list_state(what)` | Inspect `summary` / `nodes` / `skills` / `items` / `config`. |

### Mutation + export

| Tool | What it does |
|------|--------------|
| `allocate_nodes(node_ids)` | Permanently allocate passive nodes and recalculate. Returns updated DPS/Life/ES. |
| `deallocate_nodes(node_ids)` | Permanently deallocate passive nodes and recalculate. |
| `save_build(path)` | Write the current (mutated) build to a `.xml` file. Open it in the PoB GUI via **File → Load Build**. |

## Agent workflows

### Analysis only

`load_build` → `set_config("mainSocketGroup", N)` → `get_summary` →
`rank_passive_nodes` (find candidates) → `evaluate_change` (verify combinations) → iterate.

### Tune the build and apply in GUI

```
1. In PoB GUI: File → Save build → build.xml
2. Agent:
   load_build("C:/.../build.xml")
   set_config("mainSocketGroup", 3)          # pick the damage skill group
   rank_passive_nodes("CombinedDPS", 3, 10)  # find top candidates
   evaluate_change(add_nodes=[32683, 4346])  # verify the combination
   allocate_nodes([32683, 4346])             # apply permanently
   save_build("C:/.../build.xml")            # overwrite the same file
3. In PoB GUI: File → Load build → pick build.xml  ← see the changes
```

## Notes

- MCP and the PoB GUI run as **completely separate processes** — both can be open at the
  same time without interfering. Changes in MCP are not live in the GUI; use `save_build`
  then reload in the GUI.
- `set_config("mainSocketGroup", N)` switches the active skill group (1-indexed). Use
  `list_state("skills")` to see which group index corresponds to which skill.
- This folder is intentionally separate from PoB. If you keep this in a fork, consider
  adding `pob-mcp/` to `.gitignore` if you don't want it tracked alongside upstream.
- Loading a build replaces the previously loaded one; the engine holds a single build.
