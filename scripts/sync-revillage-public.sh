#!/bin/sh
set -eu

revillage_root="${1:-}"
publish_repo_url="${REVILLAGE_PUBLIC_REPO_URL:-https://github.com/germainPoloudenny/Re-Village.git}"
publish_branch="${REVILLAGE_PUBLIC_BRANCH:-public-visible}"

if [ -z "$revillage_root" ]; then
  portfolio_root="$(git rev-parse --show-toplevel)"
  revillage_root="$(dirname "$portfolio_root")/ReVillage"
fi

presentation_root="$revillage_root/portfolio-presentation"
presentation_manifest="$presentation_root/presentation.json"

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

stylesheet_source="$(manifest_asset_path stylesheet)"
favicon_source="$(manifest_asset_path favicon)"
title_source="$(manifest_asset_path title)"
lgt_source="$(manifest_asset_path loupGarouLogo)"
higurashi_source="$(manifest_asset_path higurashiLogo)"
background_source="$(manifest_asset_path background)"
hinamizawa_source="$(manifest_asset_path conceptBackground)"

remote_git() {
  if command -v git.exe >/dev/null 2>&1; then
    git.exe "$@"
  else
    git "$@"
  fi
}

remote_repo_path() {
  repo_path="$1"
  if command -v git.exe >/dev/null 2>&1 && command -v wslpath >/dev/null 2>&1; then
    wslpath -w "$repo_path"
  else
    printf '%s\n' "$repo_path"
  fi
}

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
    echo "Required public asset missing: $source_file" >&2
    exit 1
  fi

  mkdir -p "$(dirname "$target_file")"
  cp "$source_file" "$target_file"
}

worktree_root="$(mktemp -d "${TMPDIR:-/tmp}/revillage-public-visible.XXXXXX")"

cleanup() {
  rm -rf "$worktree_root"
}

trap cleanup EXIT HUP INT TERM

git clone --depth 1 --branch "$publish_branch" "$publish_repo_url" "$worktree_root" >/dev/null

(cd "$worktree_root" && git ls-files -z | xargs -0 -r rm -f --)
find "$worktree_root" -mindepth 1 -type d -empty -delete

copy_required "$stylesheet_source" "$worktree_root/css/accueil.css"
copy_required "$favicon_source" "$worktree_root/img/favicon.png"
copy_required "$title_source" "$worktree_root/montage/img/titre.png"
copy_required "$lgt_source" "$worktree_root/montage/img/logo-loup-garou-thiercelieux.png"
copy_required "$higurashi_source" "$worktree_root/montage/img/Le_sanglot_des_cigales_Logo.png"
copy_required "$background_source" "$worktree_root/montage/img/site-background.png"
copy_required "$hinamizawa_source" "$worktree_root/montage/img/hinamizawa.jpg"

index_file="$worktree_root/index.html"
css_file="$worktree_root/css/accueil.css"
favicon_version="$(asset_version "$worktree_root/img/favicon.png")"
css_version="$(asset_version "$css_file")"
title_version="$(asset_version "$worktree_root/montage/img/titre.png")"
lgt_version="$(asset_version "$worktree_root/montage/img/logo-loup-garou-thiercelieux.png")"
higurashi_version="$(asset_version "$worktree_root/montage/img/Le_sanglot_des_cigales_Logo.png")"
background_version="$(asset_version "$worktree_root/montage/img/site-background.png")"
hinamizawa_version="$(asset_version "$worktree_root/montage/img/hinamizawa.jpg")"

node - "$index_file" "$css_file" "$presentation_manifest" "$favicon_version" "$css_version" "$title_version" "$lgt_version" "$higurashi_version" "$background_version" "$hinamizawa_version" <<'NODE'
const fs = require('fs');

const [
  indexFile,
  cssFile,
  presentationManifest,
  faviconVersion,
  cssVersion,
  titleVersion,
  lgtVersion,
  higurashiVersion,
  backgroundVersion,
  hinamizawaVersion,
] = process.argv.slice(2);

const manifest = JSON.parse(fs.readFileSync(presentationManifest, 'utf8'));

if (!manifest.pitch || typeof manifest.pitch !== 'string') {
  console.error(`ReVillage portfolio pitch missing in: ${presentationManifest}`);
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

const playMarkup = manifest.play.enabled
  ? `<a class="home-play-button" href="${manifest.play.href}">${manifest.play.label}</a>`
  : `<button class="home-play-button" type="button" disabled>${manifest.play.label}</button>`;

const index = `<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>${manifest.title || 'Re:Village'}</title>
    <link rel="icon" href="./img/favicon.png?v=${faviconVersion}" type="image/png" />
    <link rel="stylesheet" href="./css/accueil.css?v=${cssVersion}" />
</head>
<body class="home-page home-splash-page">
    <main id="top">
        <section class="home-hero" aria-labelledby="homeTitle">
            <div class="home-hero-content">
                <h1 id="homeTitle" class="home-hero-title">
                    <img src="./montage/img/titre.png?v=${titleVersion}" alt="${manifest.title || 'Re:Village'}" />
                </h1>
            </div>
        </section>

        <section class="home-concept-pitch" aria-labelledby="conceptTitle">
            <div class="home-concept-inner">
                <div class="home-concept-copy">
                    <p id="conceptTitle">
                        ${manifest.pitch}
                    </p>
                </div>

                <div class="home-crossover-visual" aria-label="Le Loup-Garou de Thiercelieux croisé avec Le Sanglot des Cigales">
                    <img class="home-crossover-lgt-logo" src="./montage/img/logo-loup-garou-thiercelieux.png?v=${lgtVersion}" alt="Les Loups-Garous de Thiercelieux" />
                    <span aria-hidden="true">×</span>
                    <img class="home-crossover-higurashi-logo" src="./montage/img/Le_sanglot_des_cigales_Logo.png?v=${higurashiVersion}" alt="Le sanglot des cigales" />
                </div>
            </div>
        </section>

        <section class="home-play-section" aria-label="Accès à la session">
            ${playMarkup}
        </section>
    </main>
</body>
</html>
`;
fs.writeFileSync(indexFile, index);

let css = fs.readFileSync(cssFile, 'utf8');
css = css
  .replace(/url\("\.\.\/montage\/img\/site-background\.png(?:\?v=[^"]*)?"\)/g, `url("../montage/img/site-background.png?v=${backgroundVersion}")`)
  .replace(/url\("\.\.\/montage\/img\/hinamizawa\.jpg(?:\?v=[^"]*)?"\)/g, `url("../montage/img/hinamizawa.jpg?v=${hinamizawaVersion}")`);
fs.writeFileSync(cssFile, css);
NODE

git -C "$worktree_root" add -A

if git -C "$worktree_root" diff --cached --quiet; then
  echo "No ReVillage public-visible changes to commit."
else
  git -C "$worktree_root" commit -m "Met a jour la page publique ReVillage"
fi

remote_git -C "$(remote_repo_path "$worktree_root")" push origin "$publish_branch"
