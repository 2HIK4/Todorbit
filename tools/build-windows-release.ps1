param([string]$GoogleDriveConfigPath = '', [switch]$PrivateDriveTest)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'google-drive-release-config.ps1')
. (Join-Path $PSScriptRoot 'dev/native-command.ps1')
. (Join-Path $PSScriptRoot 'windows-crt.ps1')
$configPath = if ($GoogleDriveConfigPath) {
  (Resolve-Path -LiteralPath $GoogleDriveConfigPath -ErrorAction Stop).Path
} else { Join-Path $repo 'config\google-drive.json' }
$config = Read-GoogleDriveReleaseConfig $configPath
$previousPrivateBuildEnvironment = $env:TODORBIT_PRIVATE_DRIVE_TEST_BUILD
$env:TODORBIT_PRIVATE_DRIVE_TEST_BUILD = if ($PrivateDriveTest) { '1' } else { $null }
Push-Location $repo
try {
  $buildArguments = @('build','windows','--release','--no-pub',"--dart-define-from-file=$configPath")
  if ($PrivateDriveTest) { $buildArguments += '--dart-define=TODORBIT_PRIVATE_DRIVE_TEST=true' }
  Invoke-TodorbitNative -Command flutter -ArgumentList $buildArguments -FailureMessage 'Flutter Release build failed'
  $bundle = Join-Path $repo 'build\windows\x64\runner\Release'
  Copy-TodorbitWindowsCrt $bundle
  @{
    googleDriveEnabled = $config.GOOGLE_DRIVE_ENABLED
    privateDriveTest = [bool]$PrivateDriveTest
    clientId = $config.GOOGLE_DRIVE_CLIENT_ID
    configSha256 = (Get-FileHash -LiteralPath $configPath -Algorithm SHA256).Hash
    aotSha256 = (Get-FileHash -LiteralPath (Join-Path $bundle 'data\app.so') -Algorithm SHA256).Hash
    mainSha256 = (Get-FileHash -LiteralPath (Join-Path $bundle 'Todorbit.exe') -Algorithm SHA256).Hash
  } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $bundle 'data\todorbit-build.json') -Encoding UTF8
  Assert-GoogleDriveReleaseBundle $bundle $repo $configPath
} finally {
  Pop-Location
  $env:TODORBIT_PRIVATE_DRIVE_TEST_BUILD = $previousPrivateBuildEnvironment
}
