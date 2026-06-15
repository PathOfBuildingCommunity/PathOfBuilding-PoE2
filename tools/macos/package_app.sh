#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
build_dir="${repo_root}/build/macos-arm64"
dist_dir="${repo_root}/dist/macos-arm64"
runtime_dir="${repo_root}/runtime-macos-arm64"
app_src="${build_dir}/PathOfBuilding-PoE2.app"
app_dst="${dist_dir}/Path of Building (PoE2).app"

"${repo_root}/tools/macos/fetch_fonts.sh"
"${repo_root}/tools/macos/build_app.sh"

rm -rf "${dist_dir}"
mkdir -p "${dist_dir}"
cp -R "${app_src}" "${app_dst}"

resources="${app_dst}/Contents/Resources"
mkdir -p "${resources}"
rsync -a --delete \
  --exclude 'Export' \
  --exclude 'Builds' \
  --exclude 'Settings.xml' \
  --exclude 'HeadlessWrapper.lua' \
  --exclude 'LaunchInstall.lua' \
  "${repo_root}/src" "${resources}/"

mkdir -p "${resources}/runtime/SimpleGraphic"
rsync -a "${repo_root}/runtime/SimpleGraphic/" "${resources}/runtime/SimpleGraphic/"
rsync -a "${repo_root}/runtime/lua/" "${resources}/runtime/lua/"
# Ship a release-style manifest: tag the <Version> element with the macOS
# platform so the app does not fall into "developer mode" (which shows the
# Developer Mode warning and stores user data inside the app bundle). With a
# platform set, user data is stored under ~/Library/Application Support.
python3 - "${repo_root}/manifest.xml" "${resources}/manifest.xml" <<'PY'
import re, sys
src, dst = sys.argv[1], sys.argv[2]
text = open(src, "r", encoding="utf-8").read()
def add_platform(match):
    tag = match.group(0)
    if "platform=" in tag:
        return tag
    return tag[:-2] + ' platform="macos-arm64" />'
text = re.sub(r'<Version\b[^>]*/>', add_platform, text, count=1)
open(dst, "w", encoding="utf-8").write(text)
PY
cp "${repo_root}/changelog.txt" "${resources}/changelog.txt"
cp "${repo_root}/help.txt" "${resources}/help.txt"
cp "${repo_root}/LICENSE.md" "${resources}/LICENSE.md"

mkdir -p "${runtime_dir}"
rm -rf "${runtime_dir}/Path of Building (PoE2).app"
rsync -a "${app_dst}" "${runtime_dir}/"

zip_name="PathOfBuilding-PoE2-macos-arm64.zip"
ditto -c -k --keepParent "${app_dst}" "${dist_dir}/${zip_name}"

# Publish a SHA-256 checksum next to the zip so users can verify the download
# (see SECURITY.md). Generated with the filename only so it works with
# `shasum -a 256 -c PathOfBuilding-PoE2-macos-arm64.zip.sha256` from the
# directory containing the zip.
(
  cd "${dist_dir}"
  shasum -a 256 "${zip_name}" > "${zip_name}.sha256"
)

echo "${dist_dir}/${zip_name}"
echo "${dist_dir}/${zip_name}.sha256"
