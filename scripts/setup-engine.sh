#!/usr/bin/env bash
# Build the LuaJIT + lua-utf8 runtime the headless PoB engine needs, then set up Python and the web UI.
#
#   scripts/setup-engine.sh                 # installs into ~/.local
#   scripts/setup-engine.sh --runtime-only  # LuaJIT + lua-utf8 only (skip Python and web UI)
#   PREFIX=/usr/local sudo -E scripts/setup-engine.sh
#
# PoB uses LuaJIT syntax extensions added on 2026-07-20 (commit 2460b3ff: +=, continue, lambdas),
# so distro LuaJIT packages are too old. This pins the same commit as SimpleGraphic and the Dockerfile.
set -euo pipefail

RUNTIME_ONLY=0
[[ "${1:-}" == "--runtime-only" ]] && RUNTIME_ONLY=1

LUAJIT_COMMIT="${LUAJIT_COMMIT:-2460b3ff93a1c955de3d62cfc825de7d68dc272e}"
LUAUTF8_TAG="${LUAUTF8_TAG:-0.1.6}"
PREFIX="${PREFIX:-$HOME/.local}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

log() { printf '\033[1;33m==>\033[0m %s\n' "$*"; }

probe='local x = 1; x += 1; for i = 1, 2 do if i == 1 then continue end end'
if [[ -x "$PREFIX/bin/luajit" ]] && "$PREFIX/bin/luajit" -e "$probe" 2>/dev/null; then
  log "LuaJIT with PoB syntax support already in $PREFIX/bin"
else
  log "Building LuaJIT $LUAJIT_COMMIT into $PREFIX"
  git clone --quiet https://github.com/LuaJIT/LuaJIT "$WORK/luajit"
  git -C "$WORK/luajit" checkout --quiet "$LUAJIT_COMMIT"
  make -C "$WORK/luajit" -j"$(nproc 2>/dev/null || sysctl -n hw.ncpu)" PREFIX="$PREFIX" >/dev/null
  make -C "$WORK/luajit" install PREFIX="$PREFIX" >/dev/null
  ln -sf "$(ls "$PREFIX"/bin/luajit-2.1.* | sort | tail -1)" "$PREFIX/bin/luajit"
fi

CMOD_DIR="$PREFIX/lib/lua/5.1"
if [[ -f "$CMOD_DIR/lua-utf8.so" ]]; then
  log "lua-utf8 already installed"
else
  log "Building lua-utf8 $LUAUTF8_TAG"
  git clone --quiet --depth 1 --branch "$LUAUTF8_TAG" https://github.com/starwing/luautf8 "$WORK/luautf8"
  mkdir -p "$CMOD_DIR"
  shared="-shared"
  [[ "$(uname)" == "Darwin" ]] && shared="-bundle -undefined dynamic_lookup"
  # shellcheck disable=SC2086
  cc -O2 -fPIC $shared -I"$PREFIX/include/luajit-2.1" "$WORK/luautf8/lutf8lib.c" -o "$CMOD_DIR/lua-utf8.so"
fi

"$PREFIX/bin/luajit" -e "$probe; require('lua-utf8')" && log "LuaJIT runtime OK"
if [[ $RUNTIME_ONLY == 1 ]]; then
  exit 0
fi

if command -v uv >/dev/null; then
  log "Installing Python package (uv sync)"
  uv sync --directory "$REPO_ROOT/python" --quiet
else
  log "uv not found; install it from https://docs.astral.sh/uv/ and run: uv sync --directory python"
fi

if command -v npm >/dev/null; then
  log "Building web UI"
  (cd "$REPO_ROOT/web" && npm ci --no-audit --no-fund --silent && npm run build --silent)
else
  log "npm not found; the web UI will not be built (the REST API and MCP server still work)"
fi

case ":$PATH:" in
  *":$PREFIX/bin:"*) ;;
  *) log "Add $PREFIX/bin to PATH, or export POB2_LUAJIT=$PREFIX/bin/luajit" ;;
esac
log "Done. Try: uv run --directory python pob2-web"
