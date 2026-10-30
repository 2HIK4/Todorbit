param(
  [Parameter(Mandatory=$true)][string]$Device,
  [Parameter(Mandatory=$true)][string]$ApplicationApk,
  [string]$AndroidSdk = $env:ANDROID_HOME,
  [string]$JavaHome = $env:JAVA_HOME,
  [string]$GradleUserHome = $env:GRADLE_USER_HOME
)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'dev/native-command.ps1')
if ($Device -notmatch '^emulator-\d+$') { throw 'An explicitly named disposable emulator is required.' }
$adb = Join-Path $AndroidSdk 'platform-tools/adb.exe'
if ((& $adb -s $Device shell getprop ro.kernel.qemu).Trim() -ne '1') { throw 'Never run widget fixtures on a personal phone.' }
$apk = (Resolve-Path -LiteralPath $ApplicationApk).Path
if ($JavaHome) { $env:JAVA_HOME=$JavaHome; $env:PATH="$JavaHome/bin;$env:PATH" }
if ($AndroidSdk) { $env:ANDROID_HOME=(Resolve-Path -LiteralPath $AndroidSdk).Path; $env:ANDROID_SDK_ROOT=$env:ANDROID_HOME }
if ($GradleUserHome) { $env:GRADLE_USER_HOME=(Resolve-Path -LiteralPath $GradleUserHome).Path }
Push-Location (Join-Path $repo 'android')
try {
  Invoke-TodorbitNative -Command ./gradlew.bat -ArgumentList @(':app:assembleGithubDebugAndroidTest','-Ptarget-platform=android-arm64,android-x64') -FailureMessage 'Native widget test build failed'
} finally { Pop-Location }
# Normal in-place installation: no downgrade, uninstall or data deletion fallback.
Invoke-TodorbitNative -Command $adb -ArgumentList @('-s',$Device,'install','-r',$apk) -FailureMessage 'Development APK installation failed'
Invoke-TodorbitNative -Command $adb -ArgumentList @('-s',$Device,'install','-r',(Join-Path $repo 'build/app/outputs/apk/androidTest/github/debug/app-github-debug-androidTest.apk')) -FailureMessage 'Widget instrumentation installation failed'
$output = & $adb -s $Device shell am instrument -w -r -e isolated true io.github.hik4.todorbit.test/io.github.hik4.todorbit.WidgetRenderInstrumentation
$output
# Android's shell may exit zero even when instrumentation fails.
if ($LASTEXITCODE -ne 0 -or ($output -join "`n") -notmatch 'INSTRUMENTATION_CODE: -1' -or ($output -join "`n") -match 'INSTRUMENTATION_RESULT: failure=') {
  throw 'Native widget rendering/capability checks failed. Inspect the instrumentation output.'
}
