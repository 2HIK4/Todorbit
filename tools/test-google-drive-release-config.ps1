$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'google-drive-release-config.ps1')
$tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
$testRoot = Join-Path $tempRoot ('todorbit-oauth-package-test-' + [guid]::NewGuid().ToString('N'))
if (-not [IO.Path]::GetFullPath($testRoot).StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase)) {
  throw 'Test path escaped temporary directory.'
}
$checks = 0
function Expect-Rejected([scriptblock]$Action) {
  $rejected = $false
  try { & $Action | Out-Null } catch { $rejected = $true }
  if (-not $rejected) { throw 'Invalid or stale OAuth release configuration was accepted.' }
}
function New-VersionFixture([string]$File, [string]$FileVersion = '1.2.3.42') {
  # Real PE metadata exercises the bundle guard; this stub is never launched.
  $compiler = Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
  if (!(Test-Path -LiteralPath $compiler)) { throw 'Windows C# fixture compiler unavailable.' }
  $source = Join-Path $testRoot 'version-fixture.cs'
  @"
using System.Reflection;
[assembly: AssemblyFileVersion("$FileVersion")]
[assembly: AssemblyInformationalVersion("1.2.3-test.1+42")]
public static class Program { public static void Main() {} }
"@ | Set-Content -LiteralPath $source -Encoding UTF8
  & $compiler /nologo /target:winexe "/out:$File" $source
  if ($LASTEXITCODE -ne 0) { throw 'Version fixture compilation failed.' }
}
try {
  $configRoot = New-Item -ItemType Directory -Path (Join-Path $testRoot 'config') -Force
  $configPath = Join-Path $configRoot.FullName 'google-drive.json'
  $config = @{
    GOOGLE_DRIVE_ENABLED = $false
    GOOGLE_DRIVE_CLIENT_ID = ''
    GOOGLE_DRIVE_CLIENT_SECRET = ''
  }
  $config | ConvertTo-Json | Set-Content -LiteralPath $configPath -Encoding UTF8
  $null = Read-GoogleDriveReleaseConfig $configPath
  $checks++
  $malformedSentinel = 'SYNTHETIC-PARAMETER-MUST-NOT-LEAK'
  [IO.File]::WriteAllText($configPath, '{"GOOGLE_DRIVE_CLIENT_SECRET":"' + $malformedSentinel)
  $malformedRejected = $false
  try { Read-GoogleDriveReleaseConfig $configPath | Out-Null }
  catch {
    $malformedRejected = $true
    if ($_.Exception.Message.Contains($malformedSentinel)) {
      throw 'Malformed OAuth config exposed its field contents in the error.'
    }
  }
  if (-not $malformedRejected) { throw 'Malformed OAuth config was accepted.' }
  $checks++
  foreach ($bad in @(
    @{ GOOGLE_DRIVE_ENABLED = 'true'; GOOGLE_DRIVE_CLIENT_ID = ''; GOOGLE_DRIVE_CLIENT_SECRET = '' },
    @{ GOOGLE_DRIVE_ENABLED = $true; GOOGLE_DRIVE_CLIENT_ID = 'public.apps.googleusercontent.com'; GOOGLE_DRIVE_CLIENT_SECRET = '' },
    @{ GOOGLE_DRIVE_ENABLED = $true; GOOGLE_DRIVE_CLIENT_ID = 'https://other.invalid'; GOOGLE_DRIVE_CLIENT_SECRET = 'parameter' },
    @{ GOOGLE_DRIVE_ENABLED = $false; GOOGLE_DRIVE_CLIENT_ID = 'test.apps.googleusercontent.com'; GOOGLE_DRIVE_CLIENT_SECRET = '' },
    @{ GOOGLE_DRIVE_ENABLED = $false; GOOGLE_DRIVE_CLIENT_ID = ''; GOOGLE_DRIVE_CLIENT_SECRET = ''; refresh_token = 'must-never-ship' }
  )) {
    $bad | ConvertTo-Json | Set-Content -LiteralPath $configPath -Encoding UTF8
    Expect-Rejected { Read-GoogleDriveReleaseConfig $configPath }
    $checks++
  }
  $config.GOOGLE_DRIVE_ENABLED = $true
  $config.GOOGLE_DRIVE_CLIENT_ID = 'public.apps.googleusercontent.com'
  $config.GOOGLE_DRIVE_CLIENT_SECRET = 'public-desktop-parameter'
  $config | ConvertTo-Json | Set-Content -LiteralPath $configPath -Encoding UTF8
  $null = Read-GoogleDriveReleaseConfig $configPath
  $checks++
  $bundle = Join-Path $testRoot 'bundle'
  $null = New-Item -ItemType Directory -Path (Join-Path $bundle 'data') -Force
  'version: 1.2.3-test.1+42' | Set-Content -LiteralPath (Join-Path $testRoot 'pubspec.yaml') -Encoding UTF8
  New-VersionFixture (Join-Path $bundle 'Todorbit.exe')
  Copy-Item -LiteralPath (Join-Path $bundle 'Todorbit.exe') -Destination (Join-Path $bundle 'TodorbitWidget.exe')
  Set-Content -LiteralPath (Join-Path $bundle 'data\app.so') -Value 'fixture compiled Dart'
  Expect-Rejected { Assert-GoogleDriveReleaseBundle $bundle $testRoot }
  $checks++
  @{
    googleDriveEnabled = $true
    clientId = $config.GOOGLE_DRIVE_CLIENT_ID
    configSha256 = (Get-FileHash -LiteralPath $configPath -Algorithm SHA256).Hash
    mainSha256 = (Get-FileHash -LiteralPath (Join-Path $bundle 'Todorbit.exe') -Algorithm SHA256).Hash
    aotSha256 = (Get-FileHash -LiteralPath (Join-Path $bundle 'data\app.so') -Algorithm SHA256).Hash
  } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $bundle 'data\todorbit-build.json') -Encoding UTF8
  Assert-GoogleDriveReleaseBundle $bundle $testRoot
  $checks++
  New-VersionFixture (Join-Path $bundle 'TodorbitWidget.exe') '1.2.3.0'
  Expect-Rejected { Assert-GoogleDriveReleaseBundle $bundle $testRoot }
  $checks++
  Copy-Item -LiteralPath (Join-Path $bundle 'Todorbit.exe') -Destination (Join-Path $bundle 'TodorbitWidget.exe') -Force
  'version: 1.2.3-test.1+43' | Set-Content -LiteralPath (Join-Path $testRoot 'pubspec.yaml') -Encoding UTF8
  Expect-Rejected { Assert-GoogleDriveReleaseBundle $bundle $testRoot }
  $checks++
  'version: 1.2.3-test.1+42' | Set-Content -LiteralPath (Join-Path $testRoot 'pubspec.yaml') -Encoding UTF8
  # An approved private build can use an outside config without modifying the
  # repository default. The package still requires that exact config and AOT.
  $externalPath = Join-Path $testRoot 'approved outside config.json'
  $originalConfig = [IO.File]::ReadAllBytes($configPath)
  [IO.File]::WriteAllBytes($externalPath, $originalConfig)
  @{
    GOOGLE_DRIVE_ENABLED = $false
    GOOGLE_DRIVE_CLIENT_ID = ''
    GOOGLE_DRIVE_CLIENT_SECRET = ''
  } | ConvertTo-Json | Set-Content -LiteralPath $configPath -Encoding UTF8
  $disabledHash = (Get-FileHash -LiteralPath $configPath -Algorithm SHA256).Hash
  Expect-Rejected { Assert-GoogleDriveReleaseBundle $bundle $testRoot }
  $checks++
  Assert-GoogleDriveReleaseBundle $bundle $testRoot $externalPath
  $checks++
  $changedConfig = $config.Clone()
  $changedConfig.GOOGLE_DRIVE_CLIENT_SECRET = 'another-fixture-parameter'
  $changedConfig | ConvertTo-Json | Set-Content -LiteralPath $externalPath -Encoding UTF8
  Expect-Rejected { Assert-GoogleDriveReleaseBundle $bundle $testRoot $externalPath }
  $checks++
  [IO.File]::WriteAllBytes($externalPath, $originalConfig)
  $fixtureTools = Join-Path $testRoot 'tools'
  $null = New-Item -ItemType Directory -Path (Join-Path $fixtureTools 'dev') -Force
  Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'build-windows-release.ps1') -Destination $fixtureTools
  Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'google-drive-release-config.ps1') -Destination $fixtureTools
  @'
function Invoke-TodorbitNative {
  param($Command, $ArgumentList, $FailureMessage)
  $ArgumentList | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $repo 'fixture-build-arguments.json') -Encoding UTF8
}
'@ | Set-Content -LiteralPath (Join-Path $fixtureTools 'dev/native-command.ps1') -Encoding UTF8
  'function Copy-TodorbitWindowsCrt($Bundle) {}' | Set-Content -LiteralPath (Join-Path $fixtureTools 'windows-crt.ps1') -Encoding UTF8
  $fixtureBundle = Join-Path $testRoot 'build/windows/x64/runner/Release'
  $null = New-Item -ItemType Directory -Path (Join-Path $fixtureBundle 'data') -Force
  Copy-Item -LiteralPath (Join-Path $bundle 'Todorbit.exe') -Destination $fixtureBundle
  Copy-Item -LiteralPath (Join-Path $bundle 'TodorbitWidget.exe') -Destination $fixtureBundle
  Copy-Item -LiteralPath (Join-Path $bundle 'data/app.so') -Destination (Join-Path $fixtureBundle 'data')
  & (Join-Path $fixtureTools 'build-windows-release.ps1') -GoogleDriveConfigPath $externalPath
  $arguments = Get-Content -LiteralPath (Join-Path $testRoot 'fixture-build-arguments.json') -Raw | ConvertFrom-Json
  $privateReceipt = Get-Content -LiteralPath (Join-Path $fixtureBundle 'data/todorbit-build.json') -Raw | ConvertFrom-Json
  if ($arguments -cnotcontains "--dart-define-from-file=$externalPath" -or
      $privateReceipt.configSha256 -ne (Get-FileHash -LiteralPath $externalPath -Algorithm SHA256).Hash -or
      -not $privateReceipt.googleDriveEnabled -or
      (Get-FileHash -LiteralPath $configPath -Algorithm SHA256).Hash -ne $disabledHash) {
    throw 'Private build did not use the approved external config while preserving the default.'
  }
  if ((Get-Content -LiteralPath (Join-Path $fixtureBundle 'data/todorbit-build.json') -Raw).Contains($config.GOOGLE_DRIVE_CLIENT_SECRET)) {
    throw 'Build receipt leaked the client-secret parameter.'
  }
  $checks++
  [IO.File]::WriteAllBytes($configPath, $originalConfig)
  $credentialFile = Join-Path $bundle 'credentials.json'
  Set-Content -LiteralPath $credentialFile -Value '{"refresh_token":"fixture-only"}'
  Expect-Rejected { Assert-GoogleDriveReleaseBundle $bundle $testRoot }
  Remove-Item -LiteralPath $credentialFile
  $checks++
  Add-Content -LiteralPath (Join-Path $bundle 'data\app.so') -Value 'stale build'
  Expect-Rejected { Assert-GoogleDriveReleaseBundle $bundle $testRoot }
  $checks++
  Write-Output "PASS: $checks OAuth release configuration and stale-bundle checks."
} finally {
  if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
}
