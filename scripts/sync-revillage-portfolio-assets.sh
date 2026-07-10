#!/bin/sh
set -eu

repo_root="$(git rev-parse --show-toplevel)"
projects_root="$(dirname "$repo_root")"
revillage_root="${1:-$projects_root/ReVillage}"
source_root="$revillage_root/web"
poster_source="$revillage_root/montage/img/poster.png"
poster_destination="$repo_root/img/revillage-poster.png"
revillage_asset_dir="$repo_root/img/revillage"
index_file="$repo_root/index.html"
revillage_page="$repo_root/revillage.html"
styles_file="$repo_root/styles.css"
title_source="$source_root/montage/img/titre.png"

if [ -f "$revillage_root/montage/img/titre.png" ]; then
  title_source="$revillage_root/montage/img/titre.png"
fi

asset_version() {
  asset="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$asset" | cut -c 1-12
  else
    git hash-object "$asset" | cut -c 1-12
  fi
}

copy_required() {
  source_file="$1"
  target_file="$2"

  if [ ! -f "$source_file" ]; then
    echo "Required ReVillage portfolio asset missing: $source_file" >&2
    exit 1
  fi

  mkdir -p "$(dirname "$target_file")"
  cp "$source_file" "$target_file"
}

replace_required() {
  file="$1"
  pattern="$2"
  replacement="$3"
  label="$4"

  node - "$file" "$pattern" "$replacement" "$label" <<'NODE'
const fs = require('fs');

const [file, patternSource, replacement, label] = process.argv.slice(2);
const pattern = new RegExp(patternSource, 'g');
let content = fs.readFileSync(file, 'utf8');

if (!pattern.test(content)) {
  console.error(`${label} reference not found in: ${file}`);
  process.exit(1);
}

content = content.replace(pattern, replacement);
fs.writeFileSync(file, content);
NODE
}

mkdir -p "$(dirname "$poster_destination")"
copy_required "$poster_source" "$poster_destination"
copy_required "$title_source" "$revillage_asset_dir/titre.png"
copy_required "$source_root/montage/img/logo-loup-garou-thiercelieux.png" "$revillage_asset_dir/logo-loup-garou-thiercelieux.png"
copy_required "$source_root/montage/img/Le_sanglot_des_cigales_Logo.png" "$revillage_asset_dir/Le_sanglot_des_cigales_Logo.png"
copy_required "$source_root/montage/img/site-background.png" "$revillage_asset_dir/site-background.png"
copy_required "$source_root/montage/img/hinamizawa.jpg" "$revillage_asset_dir/hinamizawa.jpg"

poster_version="$(asset_version "$poster_destination")"
title_version="$(asset_version "$revillage_asset_dir/titre.png")"
lgt_version="$(asset_version "$revillage_asset_dir/logo-loup-garou-thiercelieux.png")"
higurashi_version="$(asset_version "$revillage_asset_dir/Le_sanglot_des_cigales_Logo.png")"
background_version="$(asset_version "$revillage_asset_dir/site-background.png")"
hinamizawa_version="$(asset_version "$revillage_asset_dir/hinamizawa.jpg")"

replace_required "$index_file" 'src="img/revillage-poster\.png(?:\?v=[^"]*)?"' "src=\"img/revillage-poster.png?v=$poster_version\"" "ReVillage poster"
replace_required "$revillage_page" 'src="img/revillage/titre\.png(?:\?v=[^"]*)?"' "src=\"img/revillage/titre.png?v=$title_version\"" "ReVillage title"
replace_required "$revillage_page" 'src="img/revillage/logo-loup-garou-thiercelieux\.png(?:\?v=[^"]*)?"' "src=\"img/revillage/logo-loup-garou-thiercelieux.png?v=$lgt_version\"" "ReVillage Loup-Garou logo"
replace_required "$revillage_page" 'src="img/revillage/Le_sanglot_des_cigales_Logo\.png(?:\?v=[^"]*)?"' "src=\"img/revillage/Le_sanglot_des_cigales_Logo.png?v=$higurashi_version\"" "ReVillage Higurashi logo"
replace_required "$styles_file" 'url\("img/revillage/site-background\.png(?:\?v=[^"]*)?"\)' "url(\"img/revillage/site-background.png?v=$background_version\")" "ReVillage background"
replace_required "$styles_file" 'url\("img/revillage/hinamizawa\.jpg(?:\?v=[^"]*)?"\)' "url(\"img/revillage/hinamizawa.jpg?v=$hinamizawa_version\")" "ReVillage concept background"

echo "Synced ReVillage portfolio assets"
