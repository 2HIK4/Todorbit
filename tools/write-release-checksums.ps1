param(
  [string]$ReleaseDirectory = ''
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$versionText = Get-Content -Raw -LiteralPath (Join-Path $repo 'pubspec.yaml')
if ($versionText -notmatch '(?m)^version:\s*([^\s+]+)') { throw 'Application version missing.' }
$version = $Matches[1]
$releaseRoot = if ($ReleaseDirectory) { [IO.Path]::GetFullPath($ReleaseDirectory) } else { Join-Path $repo 'release' }
$manifest = foreach ($suffix in @('setup.exe', 'portable.zip')) {
  $name = "Todorbit-$version-win-x64-$suffix"
  $targetFile = Join-Path $releaseRoot $name
  if (-not (Test-Path -LiteralPath $targetFile)) {
    throw "Artifact not found: $targetFile"
  }
  $hash = (Get-FileHash -LiteralPath $targetFile -Algorithm SHA256).Hash.ToLowerInvariant()
  $line = "$hash  $name"
  # Sidecars support manual verification; the updater uses GitHub asset digests.
  Set-Content -LiteralPath (Join-Path $releaseRoot "$name.sha256") -Value $line -Encoding ascii
  $line
}
$manifest | Set-Content -LiteralPath (Join-Path $releaseRoot "Todorbit-$version-SHA256SUMS.txt") -Encoding ascii
$manifest
