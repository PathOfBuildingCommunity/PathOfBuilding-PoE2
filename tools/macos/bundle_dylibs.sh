#!/usr/bin/env bash
# Make the built .app self-contained by copying its non-system dynamic
# dependencies (SDL3, LuaJIT, zstd, ...) into Contents/Frameworks and rewriting
# their install names to @executable_path/../Frameworks. Without this the
# released app references Homebrew paths like /opt/homebrew/... that do not
# exist on a downloader's Mac, so it fails to launch.
set -euo pipefail

app="${1:?usage: bundle_dylibs.sh <path-to-.app>}"
exe="${app}/Contents/MacOS/PathOfBuilding-PoE2"
frameworks="${app}/Contents/Frameworks"
fw_rpath="@executable_path/../Frameworks/"

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
  -p "${fw_rpath}" </dev/null

# dylibbundler rewrites every pre-existing LC_RPATH (one per Homebrew lib dir)
# to the same @executable_path/../Frameworks/ value, leaving the binary with
# duplicate LC_RPATH load commands -> dyld aborts at launch with
# "duplicate LC_RPATH". Collapse them to one and re-sign ad-hoc (the release
# workflow later re-signs with Developer ID; ad-hoc keeps local builds runnable
# on Apple Silicon, which requires a valid signature).
count_fw_rpath() { otool -l "$1" | grep -Fc "path ${fw_rpath} (offset" || true; }
dedupe_and_sign() {
  local f="$1" n
  n="$(count_fw_rpath "${f}")"
  while [ "${n:-0}" -gt 1 ]; do
    install_name_tool -delete_rpath "${fw_rpath}" "${f}"
    n=$((n - 1))
  done
  codesign --force --sign - "${f}" 2>/dev/null || true
}

dedupe_and_sign "${exe}"
while IFS= read -r -d '' lib; do
  dedupe_and_sign "${lib}"
done < <(find "${frameworks}" -type f \( -name '*.dylib' -o -name '*.so' \) -print0)

echo "== Dependencies AFTER bundling =="
otool -L "${exe}"

# Fail if a duplicate Frameworks rpath survived (would crash dyld at launch).
if [ "$(count_fw_rpath "${exe}")" -gt 1 ]; then
  echo "ERROR: executable still has duplicate LC_RPATH ${fw_rpath}" >&2
  exit 1
fi

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
echo "App is self-contained (single Frameworks rpath, no Homebrew/local references)."
