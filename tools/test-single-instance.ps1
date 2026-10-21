param(
  [string]$Executable = 'build\windows\x64\runner\Release\Todorbit.exe'
)

$ErrorActionPreference = 'Stop'
$binary = (Resolve-Path -LiteralPath $Executable).Path
$root = Join-Path $env:TEMP ('todorbit-instance-test-' + [guid]::NewGuid().ToString('N'))
$profiles = @(1, 2 | ForEach-Object {
  $base = Join-Path $root "profile-$_"
  $roaming = Join-Path $base 'Roaming'
  $local = Join-Path $base 'Local'
  New-Item -ItemType Directory -Path $roaming, $local -Force | Out-Null
  [pscustomobject]@{ Roaming = $roaming; Local = $local }
})
$started = [System.Collections.Generic.List[System.Diagnostics.Process]]::new()

function Start-Isolated([object]$profile, [string]$arguments = '') {
  $info = [System.Diagnostics.ProcessStartInfo]::new()
  $info.FileName = $binary
  $info.WorkingDirectory = Split-Path $binary
  $info.UseShellExecute = $false
  $info.Arguments = $arguments
  $info.Environment['APPDATA'] = $profile.Roaming
  $info.Environment['LOCALAPPDATA'] = $profile.Local
  $process = [System.Diagnostics.Process]::Start($info)
  $started.Add($process)
  return $process
}

try {
  $primary = Start-Isolated $profiles[0]
  $database = Join-Path $profiles[0].Roaming 'TodoPilot\life_manager.sqlite'
  $ready = $false
  for ($attempt = 0; $attempt -lt 150; $attempt++) {
    if (Test-Path -LiteralPath $database) { $ready = $true; break }
    Start-Sleep -Milliseconds 100
  }
  if (-not $ready) { throw 'Primary app did not finish isolated startup.' }
  $duplicates = @(for ($attempt = 0; $attempt -lt 10; $attempt++) {
    Start-Isolated $profiles[0]
  })
  foreach ($process in $duplicates) {
    if (-not $process.WaitForExit(15000) -or $process.ExitCode -ne 0) {
      throw "Secondary launch $($process.Id) failed to activate the primary app."
    }
  }
  if ($primary.HasExited) { throw 'Primary app exited unexpectedly.' }
  $independent = Start-Isolated $profiles[1]
  $secondDatabase = Join-Path $profiles[1].Roaming 'TodoPilot\life_manager.sqlite'
  $secondReady = $false
  for ($attempt = 0; $attempt -lt 150; $attempt++) {
    if (Test-Path -LiteralPath $secondDatabase) { $secondReady = $true; break }
    Start-Sleep -Milliseconds 100
  }
  if (-not $secondReady -or $independent.HasExited) {
    throw 'Independent profile did not start separately.'
  }
  Write-Output "Single-instance and profile-isolation checks passed. Disposable data: $root"
} finally {
  foreach ($process in $started) {
    if (-not $process.HasExited) {
      [void]$process.CloseMainWindow()
      if (-not $process.WaitForExit(5000)) {
        Write-Warning "Disposable process $($process.Id) did not close automatically."
      }
    }
    $process.Dispose()
  }
}
