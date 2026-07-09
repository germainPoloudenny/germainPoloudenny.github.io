#!/bin/sh
set -eu

revillage_root="${1:-}"

if [ -z "$revillage_root" ]; then
  portfolio_root="$(git rev-parse --show-toplevel)"
  revillage_root="$(dirname "$portfolio_root")/ReVillage"
fi

source_root="$revillage_root/web"
title_source="$source_root/montage/img/titre.png"

if [ ! -d "$revillage_root/.git" ]; then
  echo "ReVillage repository not found at $revillage_root." >&2
  exit 1
fi

if [ ! -d "$source_root" ]; then
  echo "ReVillage public source folder not found at $source_root." >&2
  exit 1
fi

if [ -f "$revillage_root/montage/img/titre.png" ]; then
  title_source="$revillage_root/montage/img/titre.png"
fi

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
  git -C "$revillage_root" worktree remove --force "$worktree_root" >/dev/null 2>&1 || rm -rf "$worktree_root"
}

trap cleanup EXIT HUP INT TERM

git -C "$revillage_root" fetch origin public-visible >/dev/null 2>&1 || true

if git -C "$revillage_root" show-ref --verify --quiet refs/remotes/origin/public-visible &&
  git -C "$revillage_root" show-ref --verify --quiet refs/heads/public-visible &&
  git -C "$revillage_root" merge-base --is-ancestor public-visible origin/public-visible; then
  git -C "$revillage_root" branch -f public-visible origin/public-visible >/dev/null
fi

git -C "$revillage_root" worktree add "$worktree_root" public-visible >/dev/null

(cd "$worktree_root" && git ls-files -z | xargs -0 -r rm -f --)
find "$worktree_root" -mindepth 1 -type d -empty -delete

copy_required "$source_root/index.html" "$worktree_root/index.html"
copy_required "$source_root/css/accueil.css" "$worktree_root/css/accueil.css"
copy_required "$source_root/img/favicon.png" "$worktree_root/img/favicon.png"
copy_required "$title_source" "$worktree_root/montage/img/titre.png"
copy_required "$source_root/montage/img/logo-loup-garou-thiercelieux.png" "$worktree_root/montage/img/logo-loup-garou-thiercelieux.png"
copy_required "$source_root/montage/img/Le_sanglot_des_cigales_Logo.png" "$worktree_root/montage/img/Le_sanglot_des_cigales_Logo.png"
copy_required "$source_root/montage/img/site-background.png" "$worktree_root/montage/img/site-background.png"
copy_required "$source_root/montage/img/hinamizawa.jpg" "$worktree_root/montage/img/hinamizawa.jpg"

index_file="$worktree_root/index.html"
css_file="$worktree_root/css/accueil.css"
favicon_version="$(asset_version "$worktree_root/img/favicon.png")"
css_version="$(asset_version "$css_file")"
title_version="$(asset_version "$worktree_root/montage/img/titre.png")"
lgt_version="$(asset_version "$worktree_root/montage/img/logo-loup-garou-thiercelieux.png")"
higurashi_version="$(asset_version "$worktree_root/montage/img/Le_sanglot_des_cigales_Logo.png")"
background_version="$(asset_version "$worktree_root/montage/img/site-background.png")"
hinamizawa_version="$(asset_version "$worktree_root/montage/img/hinamizawa.jpg")"

node - "$index_file" "$css_file" "$favicon_version" "$css_version" "$title_version" "$lgt_version" "$higurashi_version" "$background_version" "$hinamizawa_version" <<'NODE'
const fs = require('fs');

const [
  indexFile,
  cssFile,
  faviconVersion,
  cssVersion,
  titleVersion,
  lgtVersion,
  higurashiVersion,
  backgroundVersion,
  hinamizawaVersion,
] = process.argv.slice(2);

let index = fs.readFileSync(indexFile, 'utf8');
index = index
  .replace(/href="(?:\.\/|\/)?img\/favicon\.png(?:\?v=[^"]*)?"/g, `href="./img/favicon.png?v=${faviconVersion}"`)
  .replace(/href="\.\/css\/accueil\.css(?:\?v=[^"]*)?"/g, `href="./css/accueil.css?v=${cssVersion}"`)
  .replace(/src="\.\/montage\/img\/titre\.png(?:\?v=[^"]*)?"/g, `src="./montage/img/titre.png?v=${titleVersion}"`)
  .replace(/src="\.\/montage\/img\/logo-loup-garou-thiercelieux\.png(?:\?v=[^"]*)?"/g, `src="./montage/img/logo-loup-garou-thiercelieux.png?v=${lgtVersion}"`)
  .replace(/src="\.\/montage\/img\/Le_sanglot_des_cigales_Logo\.png(?:\?v=[^"]*)?"/g, `src="./montage/img/Le_sanglot_des_cigales_Logo.png?v=${higurashiVersion}"`)
  .replace(/<a class="home-play-button" href="\.\/connexion\.html">Jouer<\/a>/g, '<button class="home-play-button" type="button" disabled>Jouer</button>');
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

remote_git -C "$(remote_repo_path "$revillage_root")" push origin public-visible
