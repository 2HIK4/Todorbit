# Optional local workaround when Windows symlink creation is unavailable.
# Creates only missing junctions in Flutter's ignored generated plugin directory.
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$manifest = Join-Path $repo '.flutter-plugins-dependencies'
if (!(Test-Path -LiteralPath $manifest)) { throw 'Run flutter pub get first.' }
$plugins = (Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json).plugins.windows
$directory = Join-Path $repo 'windows/flutter/ephemeral/.plugin_symlinks'
New-Item -ItemType Directory -Force -Path $directory | Out-Null
foreach ($plugin in $plugins) {
  if ($plugin.name -notmatch '^[a-z][a-z0-9_]*$') { throw 'Invalid generated plugin name.' }
  $target = (Resolve-Path -LiteralPath $plugin.path).Path.TrimEnd('\','/')
  $link = Join-Path $directory $plugin.name
  if (Test-Path -LiteralPath $link) {
    $item = Get-Item -LiteralPath $link
    # PowerShell versions expose Target as either a string or a collection.
    $linkTargets = @($item.Target)
    if (!$item.LinkType -or $linkTargets.Count -ne 1 -or !$linkTargets[0] -or
        [IO.Path]::GetFullPath([string]$linkTargets[0]).TrimEnd('\','/') -ne $target) {
      throw "Existing plugin path differs: $link. Inspect it; this helper never deletes or replaces paths."
    }
  } else {
    New-Item -ItemType Junction -Path $link -Target $target | Out-Null
  }
}
Write-Output "Verified $(@($plugins).Count) generated Windows plugin links. No system settings changed."
