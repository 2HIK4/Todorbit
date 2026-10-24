param([string]$Package = '', [switch]$ExpectFailure)

$ErrorActionPreference = 'Stop'
$versionText = Get-Content -Raw 'pubspec.yaml'
if ($versionText -notmatch '(?m)^version:\s*(\d+\.\d+\.\d+)') {
  throw 'Could not read application version.'
}
$version = $Matches[1]
if (-not $Package) { $Package = "release\Todorbit-$version-win-x64-portable.zip" }
$zip = (Resolve-Path -LiteralPath $Package).Path
$script = (Resolve-Path -LiteralPath 'tools\update-helper.ps1').Path
$root = Join-Path $env:TEMP ('todorbit-portable-update-' + [guid]::NewGuid().ToString('N'))
$roaming = Join-Path $root 'Roaming'
$local = Join-Path $root 'Local'
$initial = Join-Path $root 'Initial'
$next = Join-Path $root 'Next'
New-Item -ItemType Directory -Path $roaming, $local, $initial, $next -Force | Out-Null
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
$app = $null
$helper = $null
$widgetProcess = $null

function Start-Isolated([string]$file, [string]$arguments) {
  $info = [System.Diagnostics.ProcessStartInfo]::new()
  $info.FileName = $file
  $info.WorkingDirectory = Split-Path $file
  $info.UseShellExecute = $false
  $info.Arguments = $arguments
  $info.Environment['APPDATA'] = $roaming
  $info.Environment['LOCALAPPDATA'] = $local
  return [System.Diagnostics.Process]::Start($info)
}

try {
  Expand-Archive -LiteralPath $zip -DestinationPath $initial
  Expand-Archive -LiteralPath $zip -DestinationPath $next
  $target = Join-Path $initial 'Todorbit'
  $stage = Join-Path $initial 'Staged-Todorbit'
  $safeRoot = [IO.Path]::GetFullPath($root).TrimEnd('\') + '\'
  foreach ($movePath in @((Join-Path $next 'Todorbit'), $stage)) {
    if (-not [IO.Path]::GetFullPath($movePath).StartsWith(
        $safeRoot, [StringComparison]::OrdinalIgnoreCase)) {
      throw "Move path escaped temporary directory: $movePath"
    }
  }
  Move-Item -LiteralPath (Join-Path $next 'Todorbit') -Destination $stage
  $binary = Join-Path $target 'Todorbit.exe'
  $normalized = [IO.Path]::GetFullPath($target).ToLowerInvariant()
  $hasher = [Security.Cryptography.SHA256]::Create()
  try { $bytes = $hasher.ComputeHash([Text.Encoding]::UTF8.GetBytes($normalized)) }
  finally { $hasher.Dispose() }
  $suffix = [BitConverter]::ToString($bytes).Replace('-', '').Substring(0, 16).ToLowerInvariant()
  $profile = Join-Path $roaming "TodoPilot\portable-$suffix"
  New-Item -ItemType Directory -Path $profile -Force | Out-Null
  $settings = Join-Path $profile 'widget-settings.json'
  Set-Content -LiteralPath $settings -Value '{"launchAtSignIn":false}'
  $sentinel = Join-Path $profile 'update-test-sentinel.txt'
  Set-Content -LiteralPath $sentinel -Value 'preserve isolated profile'
  $sentinelHash = (Get-FileHash -LiteralPath $sentinel -Algorithm SHA256).Hash
  $app = Start-Isolated $binary ''
  $database = Join-Path $profile 'life_manager.sqlite'
  for ($attempt = 0; $attempt -lt 150; $attempt++) {
    if (Test-Path -LiteralPath $database) { break }
    Start-Sleep -Milliseconds 100
  }
  if (-not (Test-Path -LiteralPath $database) -or $app.HasExited) {
    throw 'The disposable portable app did not open its profile.'
  }
  Start-Sleep -Seconds 3
  if ($app.HasExited) { throw 'The disposable app exited during profile startup.' }
  $seedTask = @'
import datetime, sqlite3, sys, uuid
db = sqlite3.connect(sys.argv[1])
now = datetime.datetime.now(datetime.timezone.utc).isoformat()
db.execute("INSERT INTO tasks (id, title, status, created_at, updated_at) VALUES (?, ?, 'notStarted', ?, ?)", (str(uuid.uuid4()), 'Preserve this task', now, now))
db.commit()
db.close()
'@
  $seedTaskFile = Join-Path $root 'seed-task.py'
  Set-Content -LiteralPath $seedTaskFile -Value $seedTask -Encoding utf8
  & python $seedTaskFile $database
  if ($LASTEXITCODE -ne 0) { throw 'Could not seed disposable task.' }
  $widgetBinary = Join-Path $target 'TodorbitWidget.exe'
  $widgetProcess = Start-Isolated $widgetBinary "--widget --app-exe $binary"
  Start-Sleep -Seconds 1
  if ($widgetProcess.HasExited) { throw 'The disposable widget did not start.' }
  $packageCopy = Join-Path $root 'update.zip'
  Copy-Item -LiteralPath $zip -Destination $packageCopy
  $digest = (Get-FileHash -LiteralPath $packageCopy -Algorithm SHA256).Hash
  $size = (Get-Item -LiteralPath $packageCopy).Length
  $ready = Join-Path $root 'ready.txt'
  $result = Join-Path $root 'last-install-result.txt'
  $env:APPDATA = $roaming
  $env:LOCALAPPDATA = $local
  $expectedVersion = if ($ExpectFailure) { '9.9.9' } else { $version }
  $helper = Start-Process -FilePath 'powershell.exe' -WindowStyle Hidden -PassThru -ArgumentList @(
    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $script,
    '-Mode', 'portable', '-Package', $packageCopy, '-Target', $target,
    '-Digest', $digest, '-Size', "$size", '-ParentPid', "$($app.Id)",
    '-ReadyFile', $ready, '-ExpectedVersion', $expectedVersion, '-Stage', $stage)
  for ($attempt = 0; $attempt -lt 150; $attempt++) {
    if ((Test-Path -LiteralPath $ready) -or (Test-Path -LiteralPath $result)) { break }
    Start-Sleep -Milliseconds 100
  }
  if (-not (Test-Path -LiteralPath $ready)) {
    throw "Helper did not accept handoff: $(Get-Content -LiteralPath $result -ErrorAction SilentlyContinue)"
  }
  $widget = Start-Isolated $widgetBinary "--widget-command exit --app-exe $binary"
  [void]$widget.WaitForExit(5000)
  if ($widget.ExitCode -ne 0 -or -not $widgetProcess.WaitForExit(15000)) {
    throw 'The disposable widget did not accept the exit command.'
  }
  $widget.Dispose()
  [void]$app.CloseMainWindow()
  if (-not $app.WaitForExit(15000)) { throw 'Disposable main app did not close.' }
  if (-not $helper.WaitForExit(120000)) { throw 'Helper did not finish.' }
  $receipt = Get-Content -LiteralPath $result -Raw
  if ($ExpectFailure) {
    if ($helper.ExitCode -ne 1 -or $receipt -notmatch 'does not match expected 9\.9\.9') {
      throw "Expected version mismatch and recovery, got: $receipt"
    }
  } elseif ($helper.ExitCode -ne 0 -or
      $receipt -notmatch ('Update installed: ' + [regex]::Escape($version))) {
    throw "Helper did not record a successful update: $receipt"
  }
  $widgetSettings = Get-Content -LiteralPath $settings -Raw | ConvertFrom-Json
  if ($widgetSettings.launchAtSignIn -ne $false -or
      (Get-FileHash -LiteralPath $sentinel -Algorithm SHA256).Hash -ne $sentinelHash -or
      -not (Test-Path -LiteralPath $database)) {
    throw 'The disposable profile changed or disappeared.'
  }
  $verifyTask = @'
import sqlite3, sys
db = sqlite3.connect(sys.argv[1])
task = db.execute("SELECT COUNT(*) FROM tasks WHERE title = 'Preserve this task'").fetchone()[0]
integrity = db.execute('PRAGMA integrity_check').fetchone()[0]
db.close()
sys.exit(0 if task == 1 and integrity == 'ok' else 1)
'@
  $verifyTaskFile = Join-Path $root 'verify-task.py'
  Set-Content -LiteralPath $verifyTaskFile -Value $verifyTask -Encoding utf8
  & python $verifyTaskFile $database
  if ($LASTEXITCODE -ne 0) { throw 'The disposable task or SQLite integrity did not survive.' }
  $running = @(Get-Process -Name Todorbit -ErrorAction SilentlyContinue | Where-Object {
    try { $_.Path -and [IO.Path]::GetFullPath($_.Path) -ieq $binary } catch { $false }
  })
  if ($running.Count -ne 1) { throw "Expected one restarted app; found $($running.Count)." }
  if ($ExpectFailure) {
    Write-Output 'Portable helper rollback, automatic recovery restart, and isolated profile preservation passed.'
  } else {
    Write-Output 'Portable helper swap, automatic restart, and isolated profile preservation passed.'
  }
} finally {
  $env:APPDATA = $previousAppData
  $env:LOCALAPPDATA = $previousLocalAppData
  if ($helper -and -not $helper.HasExited) { $helper.Kill() }
  if ($app -and -not $app.HasExited) { $app.Kill() }
  if ($widgetProcess -and -not $widgetProcess.HasExited) { $widgetProcess.Kill() }
  if (Test-Path -LiteralPath $initial) {
    Get-Process -Name Todorbit -ErrorAction SilentlyContinue | Where-Object {
      try { $_.Path -and $_.Path.StartsWith($initial + '\', [StringComparison]::OrdinalIgnoreCase) } catch { $false }
    } | Stop-Process -Force
  }
  if ($helper) { $helper.Dispose() }
  if ($app) { $app.Dispose() }
  if ($widgetProcess) { $widgetProcess.Dispose() }
  $resolved = [IO.Path]::GetFullPath($root)
  $temporary = [IO.Path]::GetFullPath($env:TEMP).TrimEnd('\') + '\'
  if (-not $resolved.StartsWith($temporary, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to remove a path outside the temp directory: $resolved"
  }
  Remove-Item -LiteralPath $resolved -Recurse -Force
}
