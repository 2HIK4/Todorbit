# Public Desktop OAuth configuration only. Never accept user credentials here.
function Read-GoogleDriveReleaseConfig([string]$Path) {
  $config = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
  $expected = @('GOOGLE_DRIVE_ENABLED', 'GOOGLE_DRIVE_CLIENT_ID', 'GOOGLE_DRIVE_CLIENT_SECRET')
  $keys = @($config.PSObject.Properties.Name)
  if ($keys.Count -ne 3 -or @($keys | Where-Object { $_ -cnotin $expected }).Count -ne 0 -or
      $config.GOOGLE_DRIVE_ENABLED -isnot [bool] -or
      $config.GOOGLE_DRIVE_CLIENT_ID -isnot [string] -or
      $config.GOOGLE_DRIVE_CLIENT_SECRET -isnot [string]) {
    throw 'OAuth release config must contain exactly the three documented public build fields.'
  }
  if ($config.GOOGLE_DRIVE_ENABLED) {
    if ($config.GOOGLE_DRIVE_CLIENT_ID -cnotmatch '^[A-Za-z0-9._-]+\.apps\.googleusercontent\.com$' -or
        $config.GOOGLE_DRIVE_CLIENT_ID.Length -gt 256 -or
        $config.GOOGLE_DRIVE_CLIENT_SECRET -cnotmatch '^[A-Za-z0-9_-]{1,1024}$') {
      throw 'Enabled Google Drive builds require a valid public Desktop client ID and client-secret parameter.'
    }
  } elseif ($config.GOOGLE_DRIVE_CLIENT_ID -ne '' -or $config.GOOGLE_DRIVE_CLIENT_SECRET -ne '') {
    throw 'Disabled public builds must leave both OAuth client fields empty.'
  }
  return $config
}

function Assert-GoogleDriveReleaseBundle([string]$Bundle, [string]$Repo) {
  $privateFiles = Get-ChildItem -LiteralPath $Bundle -Recurse -File | Where-Object {
    $_.Name -match '(?i)\.(sqlite|db)(-(wal|shm))?$|\.tdbackup$|\.log$|\.(pfx|p12|pem|key)$|client_secret.*\.json$|(?:credentials|tokens|desktop-oauth)\.json$|(-settings|privacy-session|pending-restore|restore-status)\.json$' -or
    $_.FullName -match '(?i)[\\/]backups[\\/]'
  }
  if ($privateFiles) { throw 'Release bundle contains private data, a user session or a downloaded credential file.' }
  $manifestPath = Join-Path $Bundle 'data\todorbit-build.json'
  if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw 'OAuth build receipt missing. Build with tools/build-windows-release.ps1 before packaging.'
  }
  $receipt = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
  $configPath = Join-Path $Repo 'config\google-drive.json'
  $config = Read-GoogleDriveReleaseConfig $configPath
  $aotHash = (Get-FileHash -LiteralPath (Join-Path $Bundle 'data\app.so') -Algorithm SHA256).Hash
  $configHash = (Get-FileHash -LiteralPath $configPath -Algorithm SHA256).Hash
  $mainHash = (Get-FileHash -LiteralPath (Join-Path $Bundle 'Todorbit.exe') -Algorithm SHA256).Hash
  if ($receipt.configSha256 -ne $configHash -or $receipt.aotSha256 -ne $aotHash -or
      $receipt.mainSha256 -ne $mainHash -or $receipt.googleDriveEnabled -ne $config.GOOGLE_DRIVE_ENABLED -or
      $receipt.clientId -cne $config.GOOGLE_DRIVE_CLIENT_ID) {
    throw 'Release bundle is stale or does not match the reviewed public OAuth configuration. Rebuild it.'
  }
}
