# Real startup and managed attachment opening must never use personal profiles.
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$receiptRoot = Join-Path $repo ".buildlog/verify/profile-journeys/$stamp-$([guid]::NewGuid().ToString('N').Substring(0,8))"
$profileRoot = Join-Path $receiptRoot 'test-profiles'
$previous = @{}
foreach ($key in @('APPDATA','LOCALAPPDATA','TODORBIT_PROFILE_JOURNEYS')) {
  $previous[$key] = [Environment]::GetEnvironmentVariable($key, 'Process')
}
$flutterBin = Split-Path (Get-Command flutter -ErrorAction Stop).Source
$dart = Join-Path $flutterBin 'cache/dart-sdk/bin/dart.exe'
$snapshot = Join-Path $flutterBin 'cache/flutter_tools.snapshot'
$arguments = @($snapshot, '--no-version-check', '--suppress-analytics', 'test', '--no-pub', '--concurrency=1', '--reporter=expanded', '--timeout=2m', 'test/startup_recovery_journeys_test.dart', 'test/resource_journeys_test.dart')
Push-Location $repo
try {
  $env:APPDATA = Join-Path $profileRoot 'Roaming'
  $env:LOCALAPPDATA = Join-Path $profileRoot 'Local'
  $env:TODORBIT_PROFILE_JOURNEYS = '1'
  New-Item -ItemType Directory -Force -Path $env:APPDATA,$env:LOCALAPPDATA | Out-Null
  $log = Join-Path $receiptRoot 'test.log'
  $source = (git rev-parse HEAD).Trim()
  $paths = @('lib/main.dart','lib/data/app_database.dart','lib/data/migration_gate.dart','lib/data/backup_service.dart','lib/data/appearance_preference_store.dart','lib/data/calendar_preference_store.dart','lib/features/workspace/task_resources_section.dart','lib/features/workspace/windows_resource_dialog.dart','test/startup_recovery_journeys_test.dart','test/resource_journeys_test.dart','test/support/profile_journey_environment.dart','test/database_initialization_test.dart','pubspec.lock')
  $hashes = @{}
  foreach ($file in $paths) { $hashes[$file] = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash }
  Write-Output "Isolated profile: $profileRoot"
  $started = Get-Date
  $ErrorActionPreference = 'Continue'
  & $dart @arguments *> $log
  $code = $LASTEXITCODE
  $ErrorActionPreference = 'Stop'
  [pscustomobject]@{
    time=$started.ToString('o'); source=$source; hashes=$hashes;
    executable=$dart; arguments=$arguments; exitCode=$code; log=$log;
    APPDATA=$env:APPDATA; LOCALAPPDATA=$env:LOCALAPPDATA
  } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $receiptRoot 'result.json') -Encoding UTF8
  Get-Content -LiteralPath $log -Tail 12
  Write-Output "Evidence retained: $receiptRoot"
  if ($code -ne 0) { throw "Profile journey tests failed (exit $code)." }
} finally {
  foreach ($key in $previous.Keys) { [Environment]::SetEnvironmentVariable($key, $previous[$key], 'Process') }
  Pop-Location
}
