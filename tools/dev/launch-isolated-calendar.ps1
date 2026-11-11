param(
  [string]$ProfileRoot = (Join-Path $env:TEMP 'todorbit-calendar-eval')
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$exe = Join-Path $repo 'build\windows\x64\runner\Debug\Todorbit.exe'

if (-not (Test-Path $exe)) {
  Write-Host "Debug executable not found at $exe. Please build it first." -ForegroundColor Red
  exit 1
}

$roaming = Join-Path $ProfileRoot 'Roaming'
$local = Join-Path $ProfileRoot 'Local'
New-Item -ItemType Directory -Force -Path $roaming, $local | Out-Null

Write-Host "Isolated profile root: $ProfileRoot" -ForegroundColor Cyan
Write-Host "Seeding synthetic calendar data into isolated profile..." -ForegroundColor Yellow

$prevAppData = $env:APPDATA
$prevLocal = $env:LOCALAPPDATA
try {
  $env:APPDATA = $roaming
  $env:LOCALAPPDATA = $local
  flutter test test/seed_isolated_calendar_profile.dart --no-pub
  if ($LASTEXITCODE -ne 0) {
    Write-Host "Database seeding failed!" -ForegroundColor Red
    exit 1
  }
} finally {
  $env:APPDATA = $prevAppData
  $env:LOCALAPPDATA = $prevLocal
}

Write-Host "Launching Todorbit in isolated environment..." -ForegroundColor Green
$startInfo = [System.Diagnostics.ProcessStartInfo]::new()
$startInfo.FileName = $exe
$startInfo.WorkingDirectory = Split-Path $exe
$startInfo.UseShellExecute = $false
$startInfo.Environment['APPDATA'] = $roaming
$startInfo.Environment['LOCALAPPDATA'] = $local
$startInfo.Environment['TODOPILOT_ISOLATED_PROFILE'] = $ProfileRoot

$proc = [System.Diagnostics.Process]::Start($startInfo)
Start-Sleep -Milliseconds 1500

if ($proc.HasExited) {
  Write-Host "Process exited unexpectedly with code $($proc.ExitCode)" -ForegroundColor Red
  exit 1
} else {
  Write-Host "Todorbit running with Process ID: $($proc.Id)" -ForegroundColor Green
  Write-Host "Data directory: $(Join-Path $roaming 'TodoPilot')" -ForegroundColor Gray
}
