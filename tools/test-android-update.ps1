param(
  [Parameter(Mandatory=$true)][string]$Device,
  [string]$AndroidSdk = $env:ANDROID_HOME,
  [string]$JavaHome = $env:JAVA_HOME,
  [string]$GradleUserHome = $env:GRADLE_USER_HOME,
  [switch]$AllowDebugDowngrade
)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'dev/native-command.ps1')
if ($Device -notmatch '^emulator-\d+$') { throw 'Only an explicitly named disposable emulator is accepted. Never run this on a personal phone.' }
$adb = Join-Path $AndroidSdk 'platform-tools/adb.exe'
if ((& $adb -s $Device shell getprop ro.kernel.qemu).Trim() -ne '1') { throw 'Device is not an Android emulator.' }
$packageInfo = (& $adb -s $Device shell dumpsys package io.github.hik4.todorbit) -join "`n"
if ($packageInfo -match 'versionCode=(\d+)' -and [int]$Matches[1] -gt 19 -and !$AllowDebugDowngrade) {
  throw 'This disposable emulator has a newer test build. Archive its test profile first, then opt in with -AllowDebugDowngrade, or use a fresh isolated AVD. No app data was removed.'
}
Push-Location $repo
try {
  # BuildNumber overrides only these development artifacts, not pubspec/Windows.
  & ./tools/build-android.ps1 -Mode Debug -BuildNumber 20 -NoPub -AndroidSdk $AndroidSdk -JavaHome $JavaHome -GradleUserHome $GradleUserHome
  $fixtures = Join-Path $repo '.buildlog/android-update-fixtures'
  Invoke-TodorbitNative -Command python -ArgumentList @('tools/android-update-fixtures.py','--sdk',$AndroidSdk,'--candidate','build/app/outputs/flutter-apk/app-github-debug.apk','--debug-keystore',"$env:USERPROFILE/.android/debug.keystore",'--output',$fixtures) -FailureMessage 'Fixture preparation failed'
  & ./tools/build-android.ps1 -Mode Debug -BuildNumber 19 -NoPub -AndroidSdk $AndroidSdk -JavaHome $JavaHome -GradleUserHome $GradleUserHome
  $installArguments = @('-s',$Device,'install','-r')
  if ($AllowDebugDowngrade) { $installArguments += '-d' }
  & $adb @installArguments build/app/outputs/flutter-apk/app-github-debug.apk
  if ($LASTEXITCODE -ne 0) { throw 'Disposable baseline installation failed.' }
  & $adb -s $Device shell run-as io.github.hik4.todorbit mkdir -p files/update-fixtures
  # Stage through adb's file-sync protocol; Windows stdin pipes can truncate APKs.
  $env:TODORBIT_FIXTURES = $fixtures
  $env:TODORBIT_TEST_ADB = $adb
  $env:TODORBIT_TEST_DEVICE = $Device
  $transferScript = @'
import hashlib, os, pathlib, subprocess
adb = [os.environ['TODORBIT_TEST_ADB'], '-s', os.environ['TODORBIT_TEST_DEVICE']]
subprocess.run(adb + ['shell', 'mkdir', '-p', '/data/local/tmp/todorbit-update-fixtures'], check=True)
for name in ['candidate.apk','wrong-package.apk','wrong-signer.apk','wrong-abi.apk','newer-sdk.apk','older.apk','tampered.apk','candidate.json']:
    apk = pathlib.Path(os.environ['TODORBIT_FIXTURES']) / name
    staged = f'/data/local/tmp/todorbit-update-fixtures/{name}'
    subprocess.run(adb + ['push', str(apk), staged], check=True)
    subprocess.run(adb + ['shell', 'run-as', 'io.github.hik4.todorbit', 'cp', staged, f'files/update-fixtures/{name}'], check=True)
    actual = subprocess.check_output(adb + ['shell', 'run-as', 'io.github.hik4.todorbit', 'sha256sum', f'files/update-fixtures/{name}']).decode().split()[0]
    if actual != hashlib.sha256(apk.read_bytes()).hexdigest():
        raise RuntimeError(f'Fixture transfer checksum mismatch: {name}')
    subprocess.run(adb + ['shell', 'rm', staged], check=True)
'@
  Invoke-TodorbitNative -Command python -ArgumentList @('-') -InputText $transferScript -FailureMessage 'Fixture transfer failed'
  # Flutter Drive also uninstalls by default; retain this archived test profile.
  Invoke-TodorbitNative -Command flutter -ArgumentList @('drive','--keep-app-running','--debug','--no-pub','--flavor','github','--driver=test_driver/android_workflow_driver.dart','--target=integration_test/android_drive_updates_test.dart','-d',$Device) -FailureMessage 'Native APK verification integration failed'
} finally { Pop-Location }
