param(
  [string]$Executable = 'build\windows\x64\runner\Release\Todorbit.exe'
)

$ErrorActionPreference = 'Stop'
$binary = (Resolve-Path -LiteralPath $Executable).Path
$root = Join-Path $env:TEMP ('todorbit-update-handoff-' + [guid]::NewGuid().ToString('N'))
$roaming = Join-Path $root 'Roaming'
$local = Join-Path $root 'Local'
New-Item -ItemType Directory -Path $roaming, $local -Force | Out-Null
$profile = Join-Path $roaming 'TodoPilot'
New-Item -ItemType Directory -Path $profile -Force | Out-Null
Set-Content -LiteralPath (Join-Path $profile 'widget-settings.json') -Value '{"launchAtSignIn":false}'
$started = [System.Collections.Generic.List[System.Diagnostics.Process]]::new()
$mutex = [System.Threading.Mutex]::new($false, 'Local\TodorbitUpdateHandoff')
$ownsMutex = $false

function Start-Isolated([string]$arguments) {
  $info = [System.Diagnostics.ProcessStartInfo]::new()
  $info.FileName = $binary
  $info.WorkingDirectory = Split-Path $binary
  $info.UseShellExecute = $false
  $info.Arguments = $arguments
  $info.Environment['APPDATA'] = $roaming
  $info.Environment['LOCALAPPDATA'] = $local
  $process = [System.Diagnostics.Process]::Start($info)
  $started.Add($process)
  return $process
}

try {
  $ownsMutex = $mutex.WaitOne(0)
  if (-not $ownsMutex) { throw 'Another update owns the handoff mutex.' }
  $blocked = Start-Isolated ''
  if (-not $blocked.WaitForExit(15000) -or $blocked.ExitCode -ne 0) {
    throw 'A normal app launch did not release its executable during update.'
  }
  $database = Join-Path $roaming 'TodoPilot\life_manager.sqlite'
  if (Test-Path -LiteralPath $database) {
    throw 'A normal app launch passed the update gate.'
  }
  $restart = Start-Isolated '--update-restart'
  for ($attempt = 0; $attempt -lt 150; $attempt++) {
    if (Test-Path -LiteralPath $database) { break }
    Start-Sleep -Milliseconds 100
  }
  if (-not (Test-Path -LiteralPath $database) -or $restart.HasExited) {
    throw 'The updater restart did not open the isolated profile.'
  }
  $mutex.ReleaseMutex()
  $ownsMutex = $false
  if ($restart.HasExited) { throw 'The restarted instance exited unexpectedly.' }
  Write-Output 'Update handoff gate passed with one isolated restarted app.'
} finally {
  if ($ownsMutex) { $mutex.ReleaseMutex() }
  $mutex.Dispose()
  foreach ($process in $started) {
    if (-not $process.HasExited) {
      [void]$process.CloseMainWindow()
      if (-not $process.WaitForExit(5000)) { $process.Kill() }
    }
    $process.Dispose()
  }
  $widget = Join-Path (Split-Path $binary) 'TodorbitWidget.exe'
  if (Test-Path -LiteralPath $widget) {
    $info = [System.Diagnostics.ProcessStartInfo]::new()
    $info.FileName = $widget
    $info.Arguments = '--widget-command exit'
    $info.UseShellExecute = $false
    $info.Environment['APPDATA'] = $roaming
    $info.Environment['LOCALAPPDATA'] = $local
    $command = [System.Diagnostics.Process]::Start($info)
    [void]$command.WaitForExit(5000)
    $command.Dispose()
  }
  if (Test-Path -LiteralPath $root) {
    $resolved = [IO.Path]::GetFullPath($root)
    $temporary = [IO.Path]::GetFullPath($env:TEMP).TrimEnd('\') + '\'
    if (-not $resolved.StartsWith($temporary, [StringComparison]::OrdinalIgnoreCase)) {
      throw "Refusing to remove a path outside the temp directory: $resolved"
    }
    Remove-Item -LiteralPath $resolved -Recurse -Force
  }
}
