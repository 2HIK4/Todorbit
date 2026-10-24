$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$bundle = Join-Path $repo 'build\windows\x64\runner\Release'
$releaseRoot = Join-Path $repo 'release'
$versionText = Get-Content -Raw (Join-Path $repo 'pubspec.yaml')
if ($versionText -notmatch '(?m)^version:\s*(\d+\.\d+\.\d+)') {
  throw 'Could not read application version.'
}
$version = $Matches[1]
foreach ($name in @('Todorbit.exe', 'TodorbitWidget.exe', 'flutter_windows.dll', 'sqlite3.dll')) {
  if (-not (Test-Path -LiteralPath (Join-Path $bundle $name))) {
    throw "Release bundle is missing $name. Run flutter build windows --release."
  }
}
$widgetVersion = (Get-Item -LiteralPath (Join-Path $bundle 'TodorbitWidget.exe')).VersionInfo.FileVersion
if ($widgetVersion -notmatch ('^' + [regex]::Escape($version) + '(?:\.|$)')) {
  throw "Widget version $widgetVersion does not match application version $version. Rebuild Windows Release."
}
if (-not (Test-Path -LiteralPath (Join-Path $bundle 'data\flutter_assets\NOTICES.Z'))) {
  throw 'Release bundle lacks Flutter license notices.'
}
$privateData = Get-ChildItem -LiteralPath $bundle -Recurse -File | Where-Object {
  $_.Name -match '(?i)\.(sqlite|db)(-(wal|shm))?$|\.log$|\.(pfx|p12|pem|key)$|(-settings|privacy-session|pending-restore|restore-status)\.json$' -or
  $_.FullName -match '(?i)[\\/]backups[\\/]'
}
if ($privateData) { throw 'Release bundle contains private data or secrets.' }
$obsoleteBinaries = Get-ChildItem -LiteralPath $bundle -Recurse -File | Where-Object {
  $_.Name -in @('life_manager.exe', 'life_manager_widget.exe', 'TodoPilot.exe', 'TodoPilotWidget.exe')
}
if ($obsoleteBinaries) { throw 'Release bundle contains obsolete executable names.' }
New-Item -ItemType Directory -Force -Path $releaseRoot | Out-Null
$stage = Join-Path ([System.IO.Path]::GetTempPath()) ('todorbit-portable-stage-' + [guid]::NewGuid().ToString('N'))
$safeTemp = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\') + '\'
$safeStage = [System.IO.Path]::GetFullPath($stage)
if (-not $safeStage.StartsWith($safeTemp, [System.StringComparison]::OrdinalIgnoreCase)) {
  throw 'Staging path escaped temporary directory.'
}
$appFolder = Join-Path $stage 'Todorbit'
try {
  New-Item -ItemType Directory -Force -Path $appFolder | Out-Null
  Get-ChildItem -LiteralPath $bundle | Where-Object {
    $_.Name -notin @('life_manager.exe', 'life_manager_widget.exe', 'TodoPilot.exe', 'TodoPilotWidget.exe')
  } | Copy-Item -Destination $appFolder -Recurse -Force
  Copy-Item -LiteralPath (Join-Path $repo 'THIRD_PARTY_NOTICES.md') -Destination $appFolder
  Copy-Item -LiteralPath (Join-Path $repo 'LICENSE') -Destination $appFolder
  Copy-Item -LiteralPath (Join-Path $repo 'third_party') -Destination $appFolder -Recurse
  Set-Content -LiteralPath (Join-Path $appFolder 'PORTABLE-MODE') -Value 'Todorbit portable profile' -Encoding ascii
  @'
Todorbit portable package

Extract the whole ZIP, then run Todorbit.exe. Keep TodorbitWidget.exe,
DLLs, and the data folder beside it. This package does not store user data
beside the executable. Each extracted location stores data in its own
%APPDATA%\TodoPilot\portable-<location-id> folder. Moving or re-extracting to
a different path changes the selected profile. Before upgrading, export a
verified SQLite backup and keep the old folder. Import that backup into a new
extraction through Backups > Import SQLite, then verify its data. Replacing
files at the exact same path should retain the profile; confirm the path in
Settings > Privacy & Data > Data profile afterward.
Older Life Manager data is never loaded automatically. On first launch,
choose Review import if prompted, or use Settings > Privacy & Data > Backups > Import SQLite.
A registered older TodoPilot installation can retain its existing profile.

The app and installer are unsigned pending release acceptance.
Third-party Flutter notices are in data\flutter_assets\NOTICES.Z.
Native .NET and SQLitePCLRaw notices are in third_party\.
'@ | Set-Content -Encoding UTF8 (Join-Path $appFolder 'PORTABLE-README.txt')
  $zip = Join-Path $releaseRoot "Todorbit-$version-win-x64-portable.zip"
  if (Test-Path -LiteralPath $zip) {
    throw "Output already exists: $zip"
  }
  Compress-Archive -LiteralPath $appFolder -DestinationPath $zip -CompressionLevel Optimal
  $archive = [System.IO.Compression.ZipFile]::OpenRead($zip)
  try {
    $names = @($archive.Entries.FullName | ForEach-Object { $_.Replace('\', '/') })
    foreach ($name in @('Todorbit/Todorbit.exe', 'Todorbit/TodorbitWidget.exe',
        'Todorbit/LICENSE', 'Todorbit/data/flutter_assets/NOTICES.Z',
        'Todorbit/third_party/DOTNET-RUNTIME-LICENSE.txt',
        'Todorbit/third_party/DOTNET-RUNTIME-THIRD-PARTY-NOTICES.txt',
        'Todorbit/third_party/DOTNET-WINDOWSDESKTOP-LICENSE.txt',
        'Todorbit/third_party/SQLITEPCLRAW-LICENSE.txt',
        'Todorbit/third_party/SQLITEPCLRAW-NOTICE.txt')) {
      if ($names -notcontains $name) { throw "Portable ZIP lacks $name" }
    }
  } finally { $archive.Dispose() }
  Get-FileHash -Algorithm SHA256 -LiteralPath $zip
} finally {
  if (Test-Path -LiteralPath $safeStage) {
    Remove-Item -LiteralPath $safeStage -Recurse -Force
  }
}
