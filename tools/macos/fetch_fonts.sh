#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fonts_dir="${repo_root}/runtime/SimpleGraphic/Fonts"
manifest="${repo_root}/manifest.xml"
base_url="https://raw.githubusercontent.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/master/runtime"

mkdir -p "${fonts_dir}"

count=0
while IFS= read -r rel_path; do
    dest="${repo_root}/runtime/${rel_path}"
    mkdir -p "$(dirname "${dest}")"
    if [[ -f "${dest}" ]]; then
        continue
    fi
    url="${base_url}/${rel_path}"
    curl -fsSL "${url}" -o "${dest}"
    count=$((count + 1))
done < <(grep -o 'SimpleGraphic/Fonts/[^"]*\.tga' "${manifest}" | sort -u)

echo "Font atlases ready in ${fonts_dir} (${count} downloaded)"
