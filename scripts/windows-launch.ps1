$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$runtimeDir = Join-Path $projectRoot 'data\windows-launcher'
$pidPath = Join-Path $runtimeDir 'server.pid'
$stdoutPath = Join-Path $runtimeDir 'server.log'
$stderrPath = Join-Path $runtimeDir 'server-error.log'
$appUrl = 'http://localhost:8080/'

function Test-ClaudioReady {
  try {
    Invoke-WebRequest -UseBasicParsing -Uri $appUrl -TimeoutSec 2 | Out-Null
    return $true
  } catch {
    return $false
  }
}

function Open-ClaudioWindow {
  $edgeCandidates = @(
    (Join-Path ${env:ProgramFiles(x86)} 'Microsoft\Edge\Application\msedge.exe'),
    (Join-Path $env:ProgramFiles 'Microsoft\Edge\Application\msedge.exe')
  )
  $edge = $edgeCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

  if ($edge) {
    Start-Process -FilePath $edge -ArgumentList "--app=$appUrl"
  } else {
    Start-Process $appUrl
  }
}

if (Test-ClaudioReady) {
  Write-Host 'Claudio FM is already running. Opening the app window...'
  Open-ClaudioWindow
  exit 0
}

if (-not (Test-Path (Join-Path $projectRoot 'node_modules'))) {
  Write-Host 'Dependencies are missing. Run npm install in the project directory first.'
  exit 1
}

if (-not (Test-Path (Join-Path $projectRoot '.env'))) {
  Write-Host 'The .env file is missing. Copy .env.example and fill in the API keys first.'
  exit 1
}

New-Item -ItemType Directory -Force -Path $runtimeDir | Out-Null
Remove-Item $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue

Write-Host 'Starting Claudio FM. Please wait...'
$commandShell = if ($env:ComSpec) { $env:ComSpec } else { 'cmd.exe' }
$process = Start-Process `
  -FilePath $commandShell `
  -ArgumentList '/d', '/s', '/c', 'npm start' `
  -WorkingDirectory $projectRoot `
  -WindowStyle Hidden `
  -RedirectStandardOutput $stdoutPath `
  -RedirectStandardError $stderrPath `
  -PassThru

Set-Content -Path $pidPath -Value $process.Id -Encoding ascii

$deadline = (Get-Date).AddMinutes(4)
while ((Get-Date) -lt $deadline) {
  if (Test-ClaudioReady) {
    Write-Host 'Claudio FM is ready. Opening the app window...'
    Open-ClaudioWindow
    exit 0
  }

  if ($process.HasExited) {
    Write-Host "Startup failed. Check the log: $stderrPath"
    exit 1
  }

  Start-Sleep -Milliseconds 750
}

Write-Host "Startup timed out. Check the log: $stdoutPath"
exit 1
