param([Parameter(Mandatory = $true)][string]$PackagesDirectory)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$packages = (Resolve-Path -LiteralPath $PackagesDirectory).Path
$stage = Join-Path $repo ('.buildlog\sandbox-acceptance-' + [guid]::NewGuid().ToString('N'))
$payload = Join-Path $stage 'payload'
$results = Join-Path $stage 'results'
$null = New-Item -ItemType Directory -Path $payload,$results
$versionText = Get-Content -LiteralPath (Join-Path $repo 'pubspec.yaml') -Raw
if ($versionText -notmatch '(?m)^version:\s*(\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?)(?:\+\d+)?\s*$') { throw 'Missing version.' }
$version = $Matches[1]
# Public asset names retain the prerelease identifier. The existing Inno
# builder deliberately uses the numeric core for registration/PE metadata.
$installerVersion = $version.Split('-')[0]
$hashes = @{}
foreach ($suffix in @('setup.exe','portable.zip')) {
  $name = "Todorbit-$version-win-x64-$suffix"
  $file = Join-Path $packages $name
  $hash = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()
  $sidecar = (Get-Content -LiteralPath "$file.sha256" -Raw).Trim()
  if ($sidecar -cne "$hash  $name") { throw 'Package sidecar mismatch.' }
  Copy-Item -LiteralPath $file -Destination $payload
  $hashes[$name] = $hash
}
$schemaSource = Get-Content -LiteralPath (Join-Path $repo 'lib/data/app_database.dart') -Raw
if ($schemaSource -notmatch 'currentSchemaVersion\s*=\s*(\d+)') { throw 'Missing schema version.' }
$schemaVersion = [int]$Matches[1]
# Keep this explicit: an unreviewed schema must not produce a false VM failure
# or silently weaken the expected schema footprint.
$tableCount = switch ($schemaVersion) {
  26 { 52 }
  27 { 53 }
  28 { 54 }
  default { throw "Review the Sandbox table count for schema $schemaVersion." }
}
@{version=$version; installerVersion=$installerVersion; hashes=$hashes; schemaVersion=$schemaVersion; tableCount=$tableCount} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $payload 'packages.json') -Encoding UTF8
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'windows-sandbox-acceptance.ps1') -Destination $payload
# Map only the two packages and this runner; never map the repository, Desktop
# OAuth JSON, profile roots, private build configuration or token storage.
$escapedPayload = [Security.SecurityElement]::Escape($payload)
$escapedResults = [Security.SecurityElement]::Escape($results)
$configuration = @"
<Configuration>
  <Networking>Enable</Networking>
  <MappedFolders>
    <MappedFolder><HostFolder>$escapedPayload</HostFolder><SandboxFolder>C:\TodorbitPackages</SandboxFolder><ReadOnly>true</ReadOnly></MappedFolder>
    <MappedFolder><HostFolder>$escapedResults</HostFolder><SandboxFolder>C:\TodorbitResults</SandboxFolder><ReadOnly>false</ReadOnly></MappedFolder>
  </MappedFolders>
  <LogonCommand><Command>powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\TodorbitPackages\windows-sandbox-acceptance.ps1</Command></LogonCommand>
</Configuration>
"@
$configuration | Set-Content -LiteralPath (Join-Path $stage 'Todorbit-Acceptance.wsb') -Encoding UTF8
Write-Output "Prepared (not executed): $(Join-Path $stage 'Todorbit-Acceptance.wsb')"
Write-Output "Bounded smoke result destination: $results"
