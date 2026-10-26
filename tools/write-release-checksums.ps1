$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$versionText = Get-Content -Raw -LiteralPath (Join-Path $repo 'pubspec.yaml')
if ($versionText -notmatch '(?m)^version:\s*(\d+\.\d+\.\d+)') { throw 'Application version missing.' }
$version = $Matches[1]
$releaseRoot = Join-Path $repo 'release'
$manifest = foreach ($suffix in @('setup.exe', 'portable.zip')) {
  $name = "Todorbit-$version-win-x64-$suffix"
  $hash = (Get-FileHash -LiteralPath (Join-Path $releaseRoot $name) -Algorithm SHA256).Hash.ToLowerInvariant()
  $line = "$hash  $name"
  # Sidecars support manual verification; the updater uses GitHub asset digests.
  Set-Content -LiteralPath (Join-Path $releaseRoot "$name.sha256") -Value $line -Encoding ascii
  $line
}
$manifest | Set-Content -LiteralPath (Join-Path $releaseRoot "Todorbit-$version-SHA256SUMS.txt") -Encoding ascii
$manifest
