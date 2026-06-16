#!/usr/bin/env bash
# Build LuaJIT from source with LUAJIT_ENABLE_OSX_HRT.
#
# Homebrew's LuaJIT is built without the Apple-Silicon hardened-runtime JIT
# path (MAP_JIT). In this app's address layout LuaJIT then can't allocate JIT
# mcode within arm64 branch range, so every hot trace aborts with MCODEAL, the
# app never JITs (runs interpreted), and it burns most of its CPU throwing the
# failed-compile error through the OS unwinder -> ~9 fps. Building with
# LUAJIT_ENABLE_OSX_HRT enables the MAP_JIT allocator and fixes it.
#
# Prints the install prefix on stdout; all build chatter goes to stderr.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
prefix="${repo_root}/build/luajit"
src="${repo_root}/build/luajit-src"
# Pinned LuaJIT v2.1 (2026-06-13). Update deliberately.
commit="194d7f2d635a11193177f0ed820ae419148f0b70"

existing="$(ls "${prefix}"/lib/libluajit-5.1.*.dylib 2>/dev/null | head -1 || true)"
if [ -n "${existing}" ]; then
  echo "LuaJIT already built: ${existing}" >&2
  echo "${prefix}"
  exit 0
fi

{
  rm -rf "${src}" "${prefix}"
  mkdir -p "${src}"
  (
    cd "${src}"
    git init -q
    git remote add origin https://github.com/LuaJIT/LuaJIT.git
    git fetch -q --depth 1 origin "${commit}"
    git checkout -q FETCH_HEAD
  )
  export MACOSX_DEPLOYMENT_TARGET=11.0
  # -DLUAJIT_ENABLE_OSX_HRT: use the MAP_JIT mcode allocator (the actual fix).
  # -Wno-return-mismatch: silence a void-return bug in LuaJIT's HRT path that
  #   newer clang rejects as an error.
  make -C "${src}" \
    XCFLAGS="-DLUAJIT_ENABLE_OSX_HRT -Wno-return-mismatch" \
    amalg -j"$(sysctl -n hw.ncpu)"
  make -C "${src}" install PREFIX="${prefix}" INSTALL_STRIP=

  # Set the dylib's install name to its real path so it resolves when the host
  # links it, and so dylibbundler can find + rebundle it into the .app.
  dylib="$(ls "${prefix}"/lib/libluajit-5.1.*.dylib | head -1)"
  install_name_tool -id "${dylib}" "${dylib}"
} >&2

echo "${prefix}"
