param(
  [ValidateSet('Debug','Profile','Release')][string]$Mode = 'Debug',
  [string]$JavaHome = $env:JAVA_HOME,
  [string]$AndroidSdk = $env:ANDROID_HOME,
  [string]$GradleUserHome = $env:GRADLE_USER_HOME,
  [switch]$Bundle,
  [switch]$GoogleDrive,
  [switch]$DisableGoogleDrive,
  [switch]$NoPub,
  [ValidateSet('github','play')][string]$Distribution = 'github',
  [int]$BuildNumber = 0
)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'dev/native-command.ps1')
if ($AndroidSdk) {
  if (!(Test-Path -LiteralPath (Join-Path $AndroidSdk 'platforms/android-36/android.jar'))) { throw 'AndroidSdk must contain API 36.' }
  $env:ANDROID_HOME = (Resolve-Path -LiteralPath $AndroidSdk).Path
  $env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
}
if ($GradleUserHome) {
  New-Item -ItemType Directory -Force -Path $GradleUserHome | Out-Null
  $env:GRADLE_USER_HOME = (Resolve-Path -LiteralPath $GradleUserHome).Path
}
if ($JavaHome) {
  if (!(Test-Path -LiteralPath (Join-Path $JavaHome 'bin/java.exe'))) { throw 'JavaHome must contain JDK 17 or newer (JDK 21 recommended).' }
  $env:JAVA_HOME = $JavaHome
  $env:PATH = "$(Join-Path $JavaHome 'bin');$env:PATH"
}
if ($Mode -eq 'Release' -and !(Test-Path -LiteralPath (Join-Path $repo 'android/key.properties'))) {
  throw 'Release signing requires android/key.properties and a durable keystore outside Git. Debug builds are for development only.'
}
Push-Location $repo
try {
  $kind = if ($Bundle) { 'appbundle' } else { 'apk' }
  $arguments = @('build',$kind,"--$($Mode.ToLowerInvariant())")
  if ($NoPub) { $arguments += '--no-pub' }
  $arguments += @('--flavor', $Distribution)
  $arguments += @('--target-platform','android-arm64,android-x64')
  if ($GoogleDrive) { $arguments += '--dart-define=GOOGLE_DRIVE_ANDROID_ENABLED=true' }
  if ($DisableGoogleDrive) { $arguments += '--dart-define=GOOGLE_DRIVE_ANDROID_ENABLED=false' }
  if ($BuildNumber -gt 0) { $arguments += @('--build-number', "$BuildNumber") }
  Invoke-TodorbitNative -Command flutter -ArgumentList $arguments -FailureMessage 'Android build failed'
  $artifact = if ($Bundle) { "build/app/outputs/bundle/$Distribution$Mode/app-$Distribution-$($Mode.ToLowerInvariant()).aab" }
    else { "build/app/outputs/flutter-apk/app-$Distribution-$($Mode.ToLowerInvariant()).apk" }
  & python (Join-Path $PSScriptRoot 'verify-android-artifact.py') $artifact
  if ($LASTEXITCODE -ne 0) { throw 'Android native alignment validation failed.' }
} finally { Pop-Location }
