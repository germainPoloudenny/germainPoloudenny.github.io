#!/bin/sh
set -eu

repo_root="$(git rev-parse --show-toplevel)"
projects_root="$(dirname "$repo_root")"
sync_script="$repo_root/scripts/sync-roman-pdf.ps1"
revillage_portfolio_sync_script="$repo_root/scripts/sync-revillage-portfolio-assets.sh"
revillage_sync_script="$repo_root/scripts/sync-revillage-public.sh"
revillage_root="$projects_root/ReVillage"
revillage_gacp_script="$revillage_root/gacp"
revillage_presentation_manifest="$revillage_root/portfolio-presentation/presentation.json"

commit_message="${*:-update}"

run_powershell() {
  if command -v pwsh >/dev/null 2>&1; then
    pwsh -NoProfile -ExecutionPolicy Bypass -File "$sync_script"
    return
  fi

  powershell_script="$sync_script"
  if command -v cygpath >/dev/null 2>&1; then
    powershell_script="$(cygpath -w "$sync_script")"
  elif command -v wslpath >/dev/null 2>&1; then
    powershell_script="$(wslpath -w "$sync_script")"
  fi

  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$powershell_script"
}

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

if [ -d "$revillage_root/.git" ]; then
  if [ ! -f "$revillage_gacp_script" ]; then
    echo "ReVillage gacp script not found at $revillage_gacp_script." >&2
    exit 1
  fi

  sh "$revillage_gacp_script" "$commit_message"
else
  echo "ReVillage repository not found at $revillage_root; skipped ReVillage branch push." >&2
fi

run_powershell

sh "$revillage_portfolio_sync_script" "$revillage_root"

git add -A

if ! git diff --cached --quiet; then
  git commit -m "$commit_message"
else
  echo "No portfolio changes to commit."
fi

current_branch="$(git branch --show-current)"
remote_git push origin "$current_branch"

if [ -f "$revillage_presentation_manifest" ]; then
  sh "$revillage_sync_script" "$revillage_root"
else
  echo "ReVillage portfolio presentation not found at $revillage_presentation_manifest; skipped public-visible push." >&2
fi
