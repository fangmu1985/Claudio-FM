$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$pidPath = Join-Path $projectRoot 'data\windows-launcher\server.pid'

function Stop-ProcessTree {
  param([int]$ProcessId)

  $children = Get-CimInstance Win32_Process -Filter "ParentProcessId = $ProcessId" -ErrorAction SilentlyContinue
  foreach ($child in $children) {
    Stop-ProcessTree -ProcessId $child.ProcessId
  }

  Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue
}

if (-not (Test-Path $pidPath)) {
  Write-Host 'No Claudio FM process started by the desktop launcher was found.'
  exit 0
}

$serverPid = [int](Get-Content $pidPath -ErrorAction Stop)
Stop-ProcessTree -ProcessId $serverPid
Remove-Item $pidPath -Force -ErrorAction SilentlyContinue
Write-Host 'Claudio FM has stopped.'
