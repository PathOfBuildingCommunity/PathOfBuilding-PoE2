#!/usr/bin/env bash
# Make the built .app self-contained by copying its non-system dynamic
# dependencies (SDL3, LuaJIT, curl, zstd, ...) into Contents/Frameworks and
# rewriting their install names to @executable_path/../Frameworks. Without this
# the released app references Homebrew paths like /opt/homebrew/... that do not
# exist on a downloader's Mac, so it fails to launch.
set -euo pipefail

app="${1:?usage: bundle_dylibs.sh <path-to-.app>}"
exe="${app}/Contents/MacOS/PathOfBuilding-PoE2"
frameworks="${app}/Contents/Frameworks"

if ! command -v dylibbundler >/dev/null 2>&1; then
  echo "Missing required tool: dylibbundler (brew install dylibbundler)" >&2
  exit 1
fi

echo "== Dependencies BEFORE bundling =="
otool -L "${exe}" || true

mkdir -p "${frameworks}"
# -of overwrite, -b bundle deps, -cd create dir, -x fix executable,
# -d dest dir, -p install path. </dev/null so a missing-lib prompt fails fast
# instead of hanging in CI.
dylibbundler -of -b -cd \
  -x "${exe}" \
  -d "${frameworks}" \
  -p "@executable_path/../Frameworks/" </dev/null

echo "== Dependencies AFTER bundling =="
otool -L "${exe}"

# Self-containedness check: no Homebrew/local paths may remain in the main
# executable or any bundled library. Fails the build if the app is not portable.
leaked="$(
  { otool -L "${exe}"; find "${frameworks}" -type f \( -name '*.dylib' -o -name '*.so' \) -exec otool -L {} \; ; } \
    | grep -E '/opt/homebrew/|/usr/local/|/opt/local/' || true
)"
if [ -n "${leaked}" ]; then
  echo "ERROR: app still references non-bundled paths:" >&2
  echo "${leaked}" >&2
  exit 1
fi
echo "App is self-contained (no Homebrew/local dylib references)."
