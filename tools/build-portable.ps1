$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$bundle = Join-Path $repo 'build\windows\x64\runner\Release'
$releaseRoot = Join-Path $repo 'release'
$versionText = Get-Content -Raw (Join-Path $repo 'pubspec.yaml')
if ($versionText -notmatch '(?m)^version:\s*(\d+\.\d+\.\d+)') {
  throw 'Could not read application version.'
}
$version = $Matches[1]
foreach ($name in @('TodoPilot.exe', 'TodoPilotWidget.exe', 'flutter_windows.dll', 'sqlite3.dll')) {
  if (-not (Test-Path -LiteralPath (Join-Path $bundle $name))) {
    throw "Release bundle is missing $name. Run flutter build windows --release."
  }
}
if (-not (Test-Path -LiteralPath (Join-Path $bundle 'data\flutter_assets\NOTICES.Z'))) {
  throw 'Release bundle lacks Flutter license notices.'
}
$privateData = Get-ChildItem -LiteralPath $bundle -Recurse -File | Where-Object {
  $_.Name -match '(?i)\.(sqlite|db)(-(wal|shm))?$|\.log$|\.pfx$|\.pem$|\.key$'
}
if ($privateData) { throw 'Release bundle contains private data or secrets.' }
New-Item -ItemType Directory -Force -Path $releaseRoot | Out-Null
$stage = Join-Path $releaseRoot ('portable-stage-' + [guid]::NewGuid().ToString('N'))
$safeRelease = [System.IO.Path]::GetFullPath($releaseRoot).TrimEnd('\') + '\'
$safeStage = [System.IO.Path]::GetFullPath($stage)
if (-not $safeStage.StartsWith($safeRelease, [System.StringComparison]::OrdinalIgnoreCase)) {
  throw 'Staging path escaped release directory.'
}
$appFolder = Join-Path $stage 'TodoPilot'
try {
  New-Item -ItemType Directory -Force -Path $appFolder | Out-Null
  Get-ChildItem -LiteralPath $bundle | Where-Object {
    $_.Name -notin @('life_manager.exe', 'life_manager_widget.exe')
  } | Copy-Item -Destination $appFolder -Recurse -Force
  Copy-Item -LiteralPath (Join-Path $repo 'THIRD_PARTY_NOTICES.md') -Destination $appFolder
  @'
TodoPilot portable package

Extract the whole ZIP, then run TodoPilot.exe. Keep TodoPilotWidget.exe,
DLLs, and the data folder beside it. This package does not store user data
beside the executable. Fresh installs store data in %APPDATA%\TodoPilot.
Older Life Manager data is never loaded automatically. On first launch,
choose Review import if prompted, or use Settings > Backups > Import SQLite.
An installed TodoPilot 1.0.0 upgrade retains its existing profile.

The app and installer are unsigned pending release acceptance.
Third-party Flutter notices are in data\flutter_assets\NOTICES.Z.
'@ | Set-Content -Encoding UTF8 (Join-Path $appFolder 'PORTABLE-README.txt')
  $zip = Join-Path $releaseRoot "TodoPilot-$version-win-x64-portable.zip"
  if (Test-Path -LiteralPath $zip) {
    throw "Output already exists: $zip"
  }
  Compress-Archive -LiteralPath $appFolder -DestinationPath $zip -CompressionLevel Optimal
  $archive = [System.IO.Compression.ZipFile]::OpenRead($zip)
  try {
    $names = @($archive.Entries.FullName | ForEach-Object { $_.Replace('\', '/') })
    foreach ($name in @('TodoPilot/TodoPilot.exe', 'TodoPilot/TodoPilotWidget.exe',
        'TodoPilot/data/flutter_assets/NOTICES.Z')) {
      if ($names -notcontains $name) { throw "Portable ZIP lacks $name" }
    }
  } finally { $archive.Dispose() }
  Get-FileHash -Algorithm SHA256 -LiteralPath $zip
} finally {
  if (Test-Path -LiteralPath $safeStage) {
    Remove-Item -LiteralPath $safeStage -Recurse -Force
  }
}
