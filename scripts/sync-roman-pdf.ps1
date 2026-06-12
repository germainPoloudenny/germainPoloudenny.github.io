[CmdletBinding()]
param(
  [switch]$CheckGitStatus
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$projectsRoot = Split-Path -Path $repoRoot -Parent
$source = Join-Path $projectsRoot "Ecrire\ouvrages\Les Esclaves\L'Astre Noir\exports\roman.pdf"
$destinationRelative = 'pdf/les-esclaves-t1-astre-noir.pdf'
$destination = Join-Path $repoRoot ($destinationRelative -replace '/', [IO.Path]::DirectorySeparatorChar)

if (-not (Test-Path -LiteralPath $source)) {
  [Console]::Error.WriteLine("Source PDF not found: $source")
  exit 1
}

New-Item -ItemType Directory -Path (Split-Path -Path $destination -Parent) -Force | Out-Null
Copy-Item -LiteralPath $source -Destination $destination -Force

Write-Host "Synced $destinationRelative from roman.pdf"

if ($CheckGitStatus) {
  Push-Location $repoRoot
  try {
    $status = git status --porcelain -- $destinationRelative
    if ($LASTEXITCODE -ne 0) {
      exit $LASTEXITCODE
    }

    if ($status) {
      [Console]::Error.WriteLine("")
      [Console]::Error.WriteLine("The PDF was updated from the writing project but is not committed yet.")
      [Console]::Error.WriteLine("Commit this file before pushing:")
      [Console]::Error.WriteLine("  $destinationRelative")
      [Console]::Error.WriteLine("")
      git status --short -- $destinationRelative
      exit 1
    }
  }
  finally {
    Pop-Location
  }
}
