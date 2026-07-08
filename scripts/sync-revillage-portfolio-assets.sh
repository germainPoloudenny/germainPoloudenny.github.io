#!/bin/sh
set -eu

repo_root="$(git rev-parse --show-toplevel)"
projects_root="$(dirname "$repo_root")"
revillage_root="${1:-$projects_root/ReVillage}"
poster_source="$revillage_root/montage/img/poster.png"
poster_destination="$repo_root/img/revillage-poster.png"
index_file="$repo_root/index.html"

if [ ! -f "$poster_source" ]; then
  echo "ReVillage poster source not found at $poster_source; skipped portfolio poster sync." >&2
  exit 0
fi

asset_version() {
  asset="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$asset" | cut -c 1-12
  else
    git hash-object "$asset" | cut -c 1-12
  fi
}

mkdir -p "$(dirname "$poster_destination")"
cp "$poster_source" "$poster_destination"

poster_version="$(asset_version "$poster_destination")"

node - "$index_file" "$poster_version" <<'NODE'
const fs = require('fs');

const [indexFile, posterVersion] = process.argv.slice(2);
const pattern = /src="img\/revillage-poster\.png(?:\?v=[^"]*)?"/g;
const replacement = `src="img/revillage-poster.png?v=${posterVersion}"`;

let index = fs.readFileSync(indexFile, 'utf8');
if (!pattern.test(index)) {
  console.error(`ReVillage poster reference not found in: ${indexFile}`);
  process.exit(1);
}

index = index.replace(pattern, replacement);
fs.writeFileSync(indexFile, index);
NODE

echo "Synced img/revillage-poster.png from ReVillage poster.png"
