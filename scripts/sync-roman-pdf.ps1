[CmdletBinding()]
param([switch]$CheckGitStatus)
$ErrorActionPreference = 'Stop'
$taskScript = Join-Path $PSScriptRoot 'sync_writing.py'
$taskArguments = @()
if ($CheckGitStatus) { $taskArguments += '--check' }
if (Get-Command py -ErrorAction SilentlyContinue) {
  & py -3 $taskScript @taskArguments
} elseif (Get-Command python -ErrorAction SilentlyContinue) {
  & python $taskScript @taskArguments
} else {
  throw 'Python 3 est requis pour synchroniser les écrits.'
}
exit $LASTEXITCODE
