#!/usr/bin/env bash
# Run a PoB busted spec under luajit in WSL. Usage: run_spec.sh <spec-relative-to-spec/>
# Sets LUA_PATH so the runtime lua libs + busted rocks resolve; runs from src/ so the
# HeadlessWrapper helper and Data/ paths work. Does NOT pass --lua (we already run under
# luajit), which avoids busted re-spawning via `sh -c` and splitting the semicolon paths.
set -e
ROOT="/mnt/c/Users/addohm/Documents/PathOfBuilding-PoE2"
cd "$ROOT/src"
export LUA_PATH="/usr/share/lua/5.1/?.lua;/usr/share/lua/5.1/?/init.lua;./?.lua;../runtime/lua/?.lua;../runtime/lua/?/init.lua;;"
export LUA_CPATH="/usr/lib64/lua/5.1/?.so;;"
export CI=true
# stdin from /dev/null so a startup promptMsg (HeadlessWrapper io.read) can't hang the run.
exec luajit /usr/sbin/busted --helper=HeadlessWrapper.lua "../spec/${1:-System}" </dev/null
