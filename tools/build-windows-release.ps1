$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'google-drive-release-config.ps1')
$configPath = Join-Path $repo 'config\google-drive.json'
$config = Read-GoogleDriveReleaseConfig $configPath
Push-Location $repo
try {
  & flutter build windows --release --no-pub "--dart-define-from-file=$configPath"
  if ($LASTEXITCODE -ne 0) { throw "Flutter Release build failed ($LASTEXITCODE)." }
  $bundle = Join-Path $repo 'build\windows\x64\runner\Release'
  @{
    googleDriveEnabled = $config.GOOGLE_DRIVE_ENABLED
    clientId = $config.GOOGLE_DRIVE_CLIENT_ID
    configSha256 = (Get-FileHash -LiteralPath $configPath -Algorithm SHA256).Hash
    aotSha256 = (Get-FileHash -LiteralPath (Join-Path $bundle 'data\app.so') -Algorithm SHA256).Hash
    mainSha256 = (Get-FileHash -LiteralPath (Join-Path $bundle 'Todorbit.exe') -Algorithm SHA256).Hash
  } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $bundle 'data\todorbit-build.json') -Encoding UTF8
  Assert-GoogleDriveReleaseBundle $bundle $repo
} finally { Pop-Location }
