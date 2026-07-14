#!/bin/sh
set -eu

repo_root="$(git rev-parse --show-toplevel)"
projects_root="$(dirname "$repo_root")"
sync_script="$repo_root/scripts/sync-roman-pdf.ps1"
revillage_root="$projects_root/ReVillage"
revillage_gacp_script="$revillage_root/gacp"

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

if [ -d "$revillage_root/.git" ] && [ -f "$revillage_gacp_script" ]; then
  sh "$revillage_gacp_script" "$commit_message"
elif [ -d "$revillage_root/.git" ]; then
  echo "ReVillage gacp script not found at $revillage_gacp_script; skipped ReVillage branch push." >&2
else
  echo "ReVillage repository not found at $revillage_root; skipped ReVillage branch push." >&2
fi

run_powershell

git add -A

if ! git diff --cached --quiet; then
  git commit -m "$commit_message"
else
  echo "No portfolio changes to commit."
fi

current_branch="$(git branch --show-current)"
remote_git push origin "$current_branch"
