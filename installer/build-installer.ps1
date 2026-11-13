param(
  [string]$Compiler = '',
  [string]$GoogleDriveConfigPath = '',
  [string]$OutputDirectory = ''
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$versionText = Get-Content -Raw (Join-Path $repo 'pubspec.yaml')
if ($versionText -notmatch '(?m)^version:\s*([^\s+]+)') {
  throw 'Could not read application version.'
}
$version = $Matches[1]
$baseVersion = if ($version -match '^(\d+\.\d+\.\d+)') { $Matches[1] } else { $version }
$buildNumber = if ($versionText -match '(?m)^version:\s*[^\s+]+\+(\d+)') { $Matches[1] } else { '0' }
$numericVersion = "$baseVersion.$buildNumber"
$bundle = Join-Path $repo 'build\windows\x64\runner\Release'
. (Join-Path $repo 'tools\google-drive-release-config.ps1')
. (Join-Path $repo 'tools\windows-crt.ps1')
Assert-GoogleDriveReleaseBundle $bundle $repo $GoogleDriveConfigPath
Assert-TodorbitWindowsCrtBundle $bundle
$mainExe = Join-Path $bundle 'Todorbit.exe'
$widgetExe = Join-Path $bundle 'TodorbitWidget.exe'
if (-not (Test-Path -LiteralPath $mainExe) -or -not (Test-Path -LiteralPath $widgetExe)) {
  throw 'Release bundle is missing. Run flutter build windows --release first.'
}
$widgetVersion = (Get-Item -LiteralPath $widgetExe).VersionInfo.FileVersion
if ($widgetVersion -notmatch ('^' + [regex]::Escape($baseVersion) + '(?:\.|$)')) {
  throw "Widget version $widgetVersion does not match application version $version. Rebuild Windows Release."
}
$privateData = Get-ChildItem -LiteralPath $bundle -Recurse -File | Where-Object {
  $_.Name -match '(?i)\.(sqlite|db)(-(wal|shm))?$|\.log$|\.(pfx|p12|pem|key)$|(-settings|privacy-session|pending-restore|restore-status|support-introduction)\.json$' -or
  $_.FullName -match '(?i)[\\/]backups[\\/]'
}
if ($privateData) {
  throw 'Release bundle contains private data or secrets. Remove it before packaging.'
}
$obsoleteBinaries = Get-ChildItem -LiteralPath $bundle -Recurse -File | Where-Object {
  $_.Name -in @('life_manager.exe', 'life_manager_widget.exe', 'TodoPilot.exe', 'TodoPilotWidget.exe')
}
if ($obsoleteBinaries) { throw 'Release bundle contains obsolete executable names.' }

if (-not $Compiler) {
  $candidates = @(
    (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 7\ISCC.exe')
    (Join-Path $env:ProgramFiles 'Inno Setup 7\ISCC.exe')
    (Join-Path $env:LOCALAPPDATA 'Temp\TodorbitCI\Todorbit-InnoSetup-7.1.0\compiler\ISCC.exe')
    'D:\vs code\Inno Setup 7\ISCC.exe'
  )
  $registryPaths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
  )
  $installed = Get-ItemProperty $registryPaths -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -like 'Inno Setup 7*' -and $_.InstallLocation }
  foreach ($entry in $installed) {
    $candidates += Join-Path $entry.InstallLocation 'ISCC.exe'
  }
  $command = Get-Command ISCC.exe -ErrorAction SilentlyContinue
  if ($command) { $candidates += $command.Source }
  $Compiler = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}
if (-not $Compiler -or -not (Test-Path -LiteralPath $Compiler)) {
  throw 'Inno Setup 7 ISCC.exe was not found. Pass -Compiler with its full path.'
}
$compilerVersion = (& $Compiler --version | Select-Object -First 1).Trim()
if ($compilerVersion -notmatch '^7\.') {
  throw "Inno Setup 7 is required; compiler reported '$compilerVersion'."
}

$outDir = if ($OutputDirectory) { [IO.Path]::GetFullPath($OutputDirectory) } else { Join-Path $repo 'release' }
if (-not (Test-Path -LiteralPath $outDir)) {
  New-Item -ItemType Directory -Force -Path $outDir | Out-Null
}

$isccArgs = @(
  "/DAppVersion=$version",
  "/DAppNumericVersion=$numericVersion",
  "/O$outDir",
  (Join-Path $PSScriptRoot 'life_manager.iss')
)
& $Compiler @isccArgs
if ($LASTEXITCODE -ne 0) { throw "ISCC failed with exit code $LASTEXITCODE" }
$artifact = Join-Path $outDir "Todorbit-$version-win-x64-setup.exe"
if (-not (Test-Path -LiteralPath $artifact)) { throw 'Installer compiler did not create expected artifact.' }
Get-FileHash -Algorithm SHA256 -LiteralPath $artifact
