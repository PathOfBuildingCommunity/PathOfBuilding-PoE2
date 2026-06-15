#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
build_dir="${repo_root}/build/macos-arm64"

for tool in cmake ninja pkg-config; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "Missing required tool: ${tool}" >&2
    exit 1
  fi
done

for package in sdl3 luajit libzstd; do
  if ! pkg-config --exists "${package}"; then
    echo "Missing pkg-config package: ${package}" >&2
    exit 1
  fi
done

cmake -S "${repo_root}/macos" -B "${build_dir}" -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build "${build_dir}"

echo "${build_dir}/PathOfBuilding-PoE2.app"
