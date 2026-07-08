#!/bin/sh
set -eu

repo_root="$(git rev-parse --show-toplevel)"
script="$repo_root/scripts/sync-roman-pdf.ps1"

run_powershell() {
  if command -v pwsh >/dev/null 2>&1; then
    pwsh -NoProfile -ExecutionPolicy Bypass -File "$script"
    return
  fi

  powershell_script="$script"
  if command -v cygpath >/dev/null 2>&1; then
    powershell_script="$(cygpath -w "$script")"
  elif command -v wslpath >/dev/null 2>&1; then
    powershell_script="$(wslpath -w "$script")"
  fi

  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$powershell_script"
}

run_powershell

destination_relatives="
pdf/les-esclaves-t1-astre-noir.pdf
data/les-esclaves-astre-noir.js
img/les-esclaves-astre-noir.png
img/revillage-tome1.png
ecrits.html
"

status="$(git status --porcelain -- $destination_relatives)"
if [ -n "$status" ]; then
  {
    echo ""
    echo "Writing assets were updated from the writing project but are not committed yet."
    echo "Commit these files before pushing:"
    for destination_relative in $destination_relatives; do
      echo "  $destination_relative"
    done
    echo ""
    git status --short -- $destination_relatives
  } >&2
  exit 1
fi
