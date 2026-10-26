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
  Set-Content -LiteralPath (Join-Path $bundle 'Todorbit.exe') -Value 'fixture executable'
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
