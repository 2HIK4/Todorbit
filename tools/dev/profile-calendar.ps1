param(
  [Parameter(Mandatory = $true)][ValidatePattern('^[a-z0-9-]+$')][string]$Run,
  [string]$ApplicationBinary = 'build/windows/x64/runner/Profile/Todorbit.exe'
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $repo
try {
  $exe = (Resolve-Path -LiteralPath $ApplicationBinary).Path
  $repoPrefix = [IO.Path]::GetFullPath($repo).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
  if (!$exe.StartsWith($repoPrefix, [StringComparison]::OrdinalIgnoreCase) -or
      (Split-Path -Leaf $exe) -ne 'Todorbit.exe' -or
      (Test-Path -LiteralPath (Join-Path (Split-Path $exe) 'PORTABLE-MODE'))) {
    throw 'Use a non-portable Windows Profile build of test_driver/driver_main.dart.'
  }
  $base = Join-Path $repo '.buildlog/refinement'
  $fixture = Join-Path $base 'fixture-v1/Roaming/TodoPilot'
  $runRoot = Join-Path $base $Run
  if (!(Test-Path -LiteralPath (Join-Path $fixture 'life_manager.sqlite')) -or
      (Test-Path -LiteralPath $runRoot)) {
    throw 'Create the isolated fixture once and supply a fresh run name.'
  }
  $roaming = Join-Path $runRoot 'Roaming'
  $local = Join-Path $runRoot 'Local'
  New-Item -ItemType Directory -Path $roaming, $local -Force | Out-Null
  Copy-Item -LiteralPath $fixture -Destination $roaming -Recurse
  '{"theme":"dark"}' | Set-Content -LiteralPath (Join-Path $roaming 'TodoPilot/appearance-settings.json')
  $previousRoaming = $env:APPDATA
  $previousLocal = $env:LOCALAPPDATA
  $previousCache = $env:PUB_CACHE
  $previousReport = $env:TODORBIT_REFINEMENT_REPORT
  $previousExe = $env:TODORBIT_REFINEMENT_EXE
  try {
    if (!$env:PUB_CACHE) { $env:PUB_CACHE = Join-Path $previousLocal 'Pub/Cache' }
    $env:APPDATA = $roaming
    $env:LOCALAPPDATA = $local
    $env:TODORBIT_REFINEMENT_REPORT = Join-Path $runRoot 'report'
    $env:TODORBIT_REFINEMENT_EXE = $exe
    flutter drive --profile --no-pub -d windows --use-application-binary "$exe" --target test_driver/driver_main.dart --driver test_driver/calendar_profile_driver.dart
    if ($LASTEXITCODE -ne 0) { throw 'Windows Calendar profile run failed.' }
  } finally {
    $env:APPDATA = $previousRoaming
    $env:LOCALAPPDATA = $previousLocal
    $env:PUB_CACHE = $previousCache
    $env:TODORBIT_REFINEMENT_REPORT = $previousReport
    $env:TODORBIT_REFINEMENT_EXE = $previousExe
  }
} finally {
  Pop-Location
}
