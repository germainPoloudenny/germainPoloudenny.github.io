[CmdletBinding()]
param(
  [switch]$CheckGitStatus
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$projectsRoot = Split-Path -Path $repoRoot -Parent
$writingRoot = Join-Path $projectsRoot "Ecrire\ouvrages\Les Esclaves\L'Astre Noir"
$pdfSource = Join-Path $writingRoot 'exports\roman.pdf'
$backCoverSource = Join-Path $writingRoot 'text\input\4eme_de_couverture.txt'
$coverSource = Join-Path $writingRoot 'img\couverture.png'
$pdfDestinationRelative = 'pdf/les-esclaves-t1-astre-noir.pdf'
$backCoverDestinationRelative = 'data/les-esclaves-astre-noir.js'
$coverDestinationRelative = 'img/les-esclaves-astre-noir.png'
$writingsPageRelative = 'ecrits.html'
$pdfDestination = Join-Path $repoRoot ($pdfDestinationRelative -replace '/', [IO.Path]::DirectorySeparatorChar)
$backCoverDestination = Join-Path $repoRoot ($backCoverDestinationRelative -replace '/', [IO.Path]::DirectorySeparatorChar)
$coverDestination = Join-Path $repoRoot ($coverDestinationRelative -replace '/', [IO.Path]::DirectorySeparatorChar)
$writingsPage = Join-Path $repoRoot $writingsPageRelative
$destinationRelatives = @($pdfDestinationRelative, $backCoverDestinationRelative, $coverDestinationRelative, $writingsPageRelative)

foreach ($source in @($pdfSource, $backCoverSource, $coverSource)) {
  if (-not (Test-Path -LiteralPath $source)) {
    [Console]::Error.WriteLine("Writing source not found: $source")
    exit 1
  }
}

New-Item -ItemType Directory -Path (Split-Path -Path $pdfDestination -Parent) -Force | Out-Null
Copy-Item -LiteralPath $pdfSource -Destination $pdfDestination -Force

New-Item -ItemType Directory -Path (Split-Path -Path $coverDestination -Parent) -Force | Out-Null
Copy-Item -LiteralPath $coverSource -Destination $coverDestination -Force

$backCover = (Get-Content -LiteralPath $backCoverSource -Raw -Encoding UTF8).Trim()
$coverVersion = (Get-FileHash -Algorithm SHA256 -LiteralPath $coverSource).Hash.Substring(0, 12).ToLowerInvariant()
$backCoverVersion = (Get-FileHash -Algorithm SHA256 -LiteralPath $backCoverSource).Hash.Substring(0, 12).ToLowerInvariant()
$assetVersion = "$coverVersion$backCoverVersion"
$writingData = [ordered]@{
  backCover = $backCover
  assetVersion = $assetVersion
}
$writingDataJson = $writingData | ConvertTo-Json -Compress
$writingDataScript = "window.portfolioWritingData = Object.freeze($writingDataJson);`n"

New-Item -ItemType Directory -Path (Split-Path -Path $backCoverDestination -Parent) -Force | Out-Null
[IO.File]::WriteAllText($backCoverDestination, $writingDataScript, [Text.UTF8Encoding]::new($false))

$writingsPageContent = [IO.File]::ReadAllText($writingsPage)
$writingDataPattern = 'data/les-esclaves-astre-noir\.js(?:\?v=[a-f0-9]+)?'
if ($writingsPageContent -notmatch $writingDataPattern) {
  [Console]::Error.WriteLine("Writing data script reference not found in: $writingsPage")
  exit 1
}
$versionedWritingData = "data/les-esclaves-astre-noir.js?v=$assetVersion"
$updatedWritingsPageContent = [regex]::Replace($writingsPageContent, $writingDataPattern, $versionedWritingData)
if ($updatedWritingsPageContent -cne $writingsPageContent) {
  [IO.File]::WriteAllText($writingsPage, $updatedWritingsPageContent, [Text.UTF8Encoding]::new($false))
}

Write-Host "Synced $pdfDestinationRelative from roman.pdf"
Write-Host "Synced $backCoverDestinationRelative from 4eme_de_couverture.txt"
Write-Host "Synced $coverDestinationRelative from couverture.png"
Write-Host "Updated cache version in $writingsPageRelative"

if ($CheckGitStatus) {
  Push-Location $repoRoot
  try {
    $status = git status --porcelain -- $destinationRelatives
    if ($LASTEXITCODE -ne 0) {
      exit $LASTEXITCODE
    }

    if ($status) {
      [Console]::Error.WriteLine("")
      [Console]::Error.WriteLine("Writing assets were updated from the writing project but are not committed yet.")
      [Console]::Error.WriteLine("Commit these files before pushing:")
      foreach ($destinationRelative in $destinationRelatives) {
        [Console]::Error.WriteLine("  $destinationRelative")
      }
      [Console]::Error.WriteLine("")
      git status --short -- $destinationRelatives
      exit 1
    }
  }
  finally {
    Pop-Location
  }
}
