#!/bin/sh
set -eu

repo_root="$(git rev-parse --show-toplevel)"
projects_root="$(dirname "$repo_root")"
revillage_root="${1:-$projects_root/ReVillage}"
presentation_root="$revillage_root/portfolio-presentation"
presentation_manifest="$presentation_root/presentation.json"
poster_destination="$repo_root/img/revillage-poster.png"
revillage_asset_dir="$repo_root/img/revillage"
index_file="$repo_root/index.html"
revillage_page="$repo_root/revillage.html"
styles_file="$repo_root/styles.css"

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
    echo "Required ReVillage portfolio presentation asset missing: $source_file" >&2
    exit 1
  fi

  mkdir -p "$(dirname "$target_file")"
  cp "$source_file" "$target_file"
}

if [ ! -f "$presentation_manifest" ]; then
  echo "ReVillage portfolio presentation manifest not found at $presentation_manifest." >&2
  exit 1
fi

manifest_asset_path() {
  asset_key="$1"

  node - "$presentation_manifest" "$presentation_root" "$asset_key" <<'NODE'
const path = require('path');
const fs = require('fs');

const [manifestFile, presentationRoot, assetKey] = process.argv.slice(2);
const manifest = JSON.parse(fs.readFileSync(manifestFile, 'utf8'));
const relativePath = manifest.assets?.[assetKey];

if (!relativePath || typeof relativePath !== 'string') {
  console.error(`ReVillage portfolio asset "${assetKey}" missing in: ${manifestFile}`);
  process.exit(1);
}

if (path.isAbsolute(relativePath) || relativePath.split(/[\\/]+/).includes('..')) {
  console.error(`ReVillage portfolio asset "${assetKey}" must stay inside portfolio-presentation: ${relativePath}`);
  process.exit(1);
}

process.stdout.write(path.join(presentationRoot, relativePath));
NODE
}

poster_source="$(manifest_asset_path poster)"
title_source="$(manifest_asset_path title)"
lgt_source="$(manifest_asset_path loupGarouLogo)"
higurashi_source="$(manifest_asset_path higurashiLogo)"
background_source="$(manifest_asset_path background)"
hinamizawa_source="$(manifest_asset_path conceptBackground)"
seer_card_source="$(manifest_asset_path seerCardTile)"
seer_token_source="$(manifest_asset_path seerToken)"

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
copy_required "$lgt_source" "$revillage_asset_dir/logo-loup-garou-thiercelieux.png"
copy_required "$higurashi_source" "$revillage_asset_dir/Le_sanglot_des_cigales_Logo.png"
copy_required "$background_source" "$revillage_asset_dir/site-background.png"
copy_required "$hinamizawa_source" "$revillage_asset_dir/hinamizawa.jpg"
copy_required "$seer_card_source" "$revillage_asset_dir/voyante-tile.png"
copy_required "$seer_token_source" "$revillage_asset_dir/voyante-token.png"

poster_version="$(asset_version "$poster_destination")"
title_version="$(asset_version "$revillage_asset_dir/titre.png")"
lgt_version="$(asset_version "$revillage_asset_dir/logo-loup-garou-thiercelieux.png")"
higurashi_version="$(asset_version "$revillage_asset_dir/Le_sanglot_des_cigales_Logo.png")"
background_version="$(asset_version "$revillage_asset_dir/site-background.png")"
hinamizawa_version="$(asset_version "$revillage_asset_dir/hinamizawa.jpg")"
seer_card_version="$(asset_version "$revillage_asset_dir/voyante-tile.png")"
seer_token_version="$(asset_version "$revillage_asset_dir/voyante-token.png")"

replace_required "$index_file" 'src="img/revillage-poster\.png(?:\?v=[^"]*)?"' "src=\"img/revillage-poster.png?v=$poster_version\"" "ReVillage poster"
replace_required "$revillage_page" 'src="img/revillage/titre\.png(?:\?v=[^"]*)?"' "src=\"img/revillage/titre.png?v=$title_version\"" "ReVillage title"
replace_required "$revillage_page" 'src="img/revillage/logo-loup-garou-thiercelieux\.png(?:\?v=[^"]*)?"' "src=\"img/revillage/logo-loup-garou-thiercelieux.png?v=$lgt_version\"" "ReVillage Loup-Garou logo"
replace_required "$revillage_page" 'src="img/revillage/Le_sanglot_des_cigales_Logo\.png(?:\?v=[^"]*)?"' "src=\"img/revillage/Le_sanglot_des_cigales_Logo.png?v=$higurashi_version\"" "ReVillage Higurashi logo"
replace_required "$revillage_page" 'src="img/revillage/voyante-token\.png(?:\?v=[^"]*)?"' "src=\"img/revillage/voyante-token.png?v=$seer_token_version\"" "ReVillage seer token"
replace_required "$styles_file" 'url\("img/revillage/site-background\.png(?:\?v=[^"]*)?"\)' "url(\"img/revillage/site-background.png?v=$background_version\")" "ReVillage background"
replace_required "$styles_file" 'url\("img/revillage/hinamizawa\.jpg(?:\?v=[^"]*)?"\)' "url(\"img/revillage/hinamizawa.jpg?v=$hinamizawa_version\")" "ReVillage concept background"
replace_required "$styles_file" 'url\("img/revillage/voyante-tile\.png(?:\?v=[^"]*)?"\)' "url(\"img/revillage/voyante-tile.png?v=$seer_card_version\")" "ReVillage seer card background"

node - "$revillage_page" "$presentation_manifest" <<'NODE'
const fs = require('fs');

const [revillagePage, presentationManifest] = process.argv.slice(2);
const manifest = JSON.parse(fs.readFileSync(presentationManifest, 'utf8'));
let page = fs.readFileSync(revillagePage, 'utf8');

if (!manifest.pitch || typeof manifest.pitch !== 'string') {
  console.error(`ReVillage portfolio pitch missing in: ${presentationManifest}`);
  process.exit(1);
}

if (!manifest.role?.title || !manifest.role?.description) {
  console.error(`ReVillage portfolio role content missing in: ${presentationManifest}`);
  process.exit(1);
}

if (!Number.isFinite(manifest.cardEyes?.maxYawDegrees)
  || !Number.isFinite(manifest.cardEyes?.maxPitchDegrees)
  || !Number.isFinite(manifest.cardEyes?.trackingEase)) {
  console.error(`ReVillage portfolio eye settings missing in: ${presentationManifest}`);
  process.exit(1);
}

if (!Number.isInteger(manifest.cardGrid?.rowsPerViewport)
  || manifest.cardGrid.rowsPerViewport <= 0
  || !Number.isFinite(manifest.cardGrid?.oddRowOffsetRatio)) {
  console.error(`ReVillage portfolio card grid settings missing in: ${presentationManifest}`);
  process.exit(1);
}

if (!manifest.play?.label || typeof manifest.play.label !== 'string') {
  console.error(`ReVillage portfolio play label missing in: ${presentationManifest}`);
  process.exit(1);
}

if (manifest.play.enabled && (!manifest.play.href || typeof manifest.play.href !== 'string')) {
  console.error(`ReVillage portfolio play href missing in: ${presentationManifest}`);
  process.exit(1);
}

page = page.replace(
  /(<p id="revillageConceptTitle">\s*)[\s\S]*?(\s*<\/p>)/,
  `$1${manifest.pitch}$2`
);

page = page.replace(
  /(<h2 id="revillageRoleTitle">)[\s\S]*?(<\/h2>)/,
  `$1${manifest.role.title}$2`
);

page = page.replace(
  /(<div class="revillage-role-copy">[\s\S]*?<p>\s*)[\s\S]*?(\s*<\/p>)/,
  `$1${manifest.role.description}$2`
);

page = page.replace(
  /(<section class="revillage-role" aria-labelledby="revillageRoleTitle")([^>]*)>/,
  `$1 data-eye-max-yaw="${manifest.cardEyes.maxYawDegrees}" data-eye-max-pitch="${manifest.cardEyes.maxPitchDegrees}" data-eye-tracking-ease="${manifest.cardEyes.trackingEase}" data-card-rows="${manifest.cardGrid.rowsPerViewport}" data-card-odd-row-offset="${manifest.cardGrid.oddRowOffsetRatio}">`
);

const playMarkup = manifest.play.enabled
  ? `<a class="revillage-play-button" href="${manifest.play.href}">${manifest.play.label}</a>`
  : `<button class="revillage-play-button" type="button" disabled>${manifest.play.label}</button>`;

page = page.replace(
  /<(?:a|button) class="revillage-play-button"[\s\S]*?<\/(?:a|button)>/,
  playMarkup
);

fs.writeFileSync(revillagePage, page);
NODE

echo "Synced ReVillage portfolio assets"
