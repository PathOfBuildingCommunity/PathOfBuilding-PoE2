<!-- code-review-graph MCP tools -->
## MCP Tools: code-review-graph

**IMPORTANT: This project has a knowledge graph. ALWAYS use the
code-review-graph MCP tools BEFORE using Grep/Glob/Read to explore
the codebase.** The graph is faster, cheaper (fewer tokens), and gives
you structural context (callers, dependents, test coverage) that file
scanning cannot.

### When to use graph tools FIRST

- **Exploring code**: `semantic_search_nodes` or `query_graph` instead of Grep
- **Understanding impact**: `get_impact_radius` instead of manually tracing imports
- **Code review**: `detect_changes` + `get_review_context` instead of reading entire files
- **Finding relationships**: `query_graph` with callers_of/callees_of/imports_of/tests_for
- **Architecture questions**: `get_architecture_overview` + `list_communities`

Fall back to Grep/Glob/Read **only** when the graph doesn't cover what you need.

### Key Tools

| Tool | Use when |
|------|----------|
| `detect_changes` | Reviewing code changes — gives risk-scored analysis |
| `get_review_context` | Need source snippets for review — token-efficient |
| `get_impact_radius` | Understanding blast radius of a change |
| `get_affected_flows` | Finding which execution paths are impacted |
| `query_graph` | Tracing callers, callees, imports, tests, dependencies |
| `semantic_search_nodes` | Finding functions/classes by name or keyword |
| `get_architecture_overview` | Understanding high-level codebase structure |
| `refactor_tool` | Planning renames, finding dead code |

### Workflow

1. The graph auto-updates on file changes (via hooks).
2. Use `detect_changes` for code review.
3. Use `get_affected_flows` to understand impact.
4. Use `query_graph` pattern="tests_for" to check coverage.

---

# Path of Building 2 — Agent Instructions

You are working on a fork of PathOfBuildingCommunity/PathOfBuilding-PoE2, an
offline build planner for Path of Exile 2. The codebase is ~100% Lua (5.1 / LuaJIT).

## Critical rules

1. **Never break numeric calculations.** PoB's value is in correctly modelling
   PoE2's stat math. If you touch anything in `src/Modules/Calcs/` or `src/Modules/CalcSections.lua`,
   you MUST add or update tests in `spec/System/` that assert specific stat values
   within tolerance (±0.01 for DPS, exact for hit point pools).

2. **Modifier parsing is fragile.** `src/Modules/ModParser.lua` is the single most
   load-bearing file. Any change requires:
   - Adding test cases for the new modifier strings in `spec/System/TestModParser.lua`
   - Verifying existing test suite still passes (`docker compose run --rm tests`)

3. **Data file changes need validation.** Game data lives in `src/Data/`. After
   modifying any data file, run the data validation tests (`docker compose run --rm tests --tags data`).

4. **Lua nil-safety is your responsibility.** Lua does not have a type system.
   When you call `someTable.field.subfield`, guard with `someTable and someTable.field and someTable.field.subfield`
   or use `rawget`. Nil reference crashes are the #1 source of bug reports in PoB.

5. **Performance matters in calculation hot loops.** Avoid table allocations
   inside `Calc:Build*` functions; reuse tables and use local variable caching
   for frequently-accessed table fields.

## How to test changes

```bash
docker compose run --rm tests                    # full Busted suite
docker compose run --rm tests --tags builds      # build snapshot tests (slow)
docker compose run --rm tests --tags data        # data file validation only
docker compose run --rm tests --coverage         # with luacov
```

## How to validate before opening a PR

1. All tests pass: `docker compose run --rm tests`
2. Coverage did not drop: compare `luacov.report.out` against main
3. No new luac warnings: `luac -p src/**/*.lua`
4. The commit message follows Conventional Commits (`feat:`, `fix:`, `refactor:`, etc.)

## Project structure

- `src/` — main Lua source. Entrypoint is `src/Launch.lua`.
- `src/Modules/Calcs/` — the calculation engine. The most important code in the project.
- `src/Modules/ModParser.lua` — converts modifier strings into structured stat objects.
- `src/Data/` — game data: gems, items, passive tree, base item types.
- `spec/System/` — Busted test suite.
- `runtime/lua/` — extra Lua libraries used at runtime.
- `tests/` — Docker-based test harness.
