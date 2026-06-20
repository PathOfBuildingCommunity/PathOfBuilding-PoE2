#!/usr/bin/env bash
# Codesign (Developer ID + hardened runtime + LuaJIT entitlements), notarize,
# and staple the packaged .app, then regenerate the distributable zip + sha256.
#
# Expects the app already built, assembled and dylib-bundled by package_app.sh
# at dist/macos-arm64/Path of Building (PoE2).app.
#
# Credentials (provided by the release workflow from repo secrets):
#   Signing  : a Developer ID Application identity present in the keychain.
#              Override the auto-detected identity with MACOS_SIGN_IDENTITY.
#   Notarize : App Store Connect API key  -> NOTARY_KEY (base64 .p8),
#              NOTARY_KEY_ID, NOTARY_ISSUER_ID
#          or  Apple ID                   -> NOTARY_APPLE_ID, NOTARY_PASSWORD
#              (app-specific password), NOTARY_TEAM_ID
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
dist_dir="${repo_root}/dist/macos-arm64"
app="${dist_dir}/Path of Building (PoE2).app"
entitlements="${repo_root}/macos/PathOfBuilding-PoE2.entitlements"
zip_name="PathOfBuilding-PoE2-macos-arm64.zip"

[ -d "${app}" ] || { echo "Built app not found: ${app}" >&2; exit 1; }

# --- Resolve signing identity -------------------------------------------------
identity="${MACOS_SIGN_IDENTITY:-}"
if [ -z "${identity}" ]; then
  identity="$(security find-identity -v -p codesigning \
    | awk -F'"' '/Developer ID Application/{print $2; exit}')"
fi
[ -n "${identity}" ] || { echo "No 'Developer ID Application' identity in keychain" >&2; exit 1; }
echo "Signing identity: ${identity}"

# --- Codesign inside-out (bundled libs first, then the app) -------------------
if [ -d "${app}/Contents/Frameworks" ]; then
  find "${app}/Contents/Frameworks" -type f \( -name '*.dylib' -o -name '*.so' \) -print0 \
    | while IFS= read -r -d '' lib; do
        codesign --force --options runtime --timestamp -s "${identity}" "${lib}"
      done
fi
codesign --force --options runtime --timestamp \
  --entitlements "${entitlements}" -s "${identity}" "${app}"
codesign --verify --strict --verbose=2 "${app}"

# --- Notarize -----------------------------------------------------------------
submit_zip="${dist_dir}/notarize-submit.zip"
ditto -c -k --keepParent "${app}" "${submit_zip}"

if [ -n "${NOTARY_KEY:-}" ]; then
  key_file="$(mktemp /tmp/notary_key.XXXXXX.p8)"
  printf '%s' "${NOTARY_KEY}" | base64 --decode > "${key_file}"
  trap 'rm -f "${key_file}"' EXIT
  xcrun notarytool submit "${submit_zip}" \
    --key "${key_file}" --key-id "${NOTARY_KEY_ID}" --issuer "${NOTARY_ISSUER_ID}" \
    --wait
elif [ -n "${NOTARY_APPLE_ID:-}" ]; then
  xcrun notarytool submit "${submit_zip}" \
    --apple-id "${NOTARY_APPLE_ID}" --password "${NOTARY_PASSWORD}" --team-id "${NOTARY_TEAM_ID}" \
    --wait
else
  echo "::warning::No notarization credentials; app is signed but NOT notarized." >&2
  rm -f "${submit_zip}"
  ditto -c -k --keepParent "${app}" "${dist_dir}/${zip_name}"
  ( cd "${dist_dir}" && shasum -a 256 "${zip_name}" > "${zip_name}.sha256" )
  exit 0
fi
rm -f "${submit_zip}"

# --- Staple + final distributable zip ----------------------------------------
xcrun stapler staple "${app}"
xcrun stapler validate "${app}"
ditto -c -k --keepParent "${app}" "${dist_dir}/${zip_name}"
( cd "${dist_dir}" && shasum -a 256 "${zip_name}" > "${zip_name}.sha256" )
echo "Signed, notarized and stapled: ${dist_dir}/${zip_name}"
