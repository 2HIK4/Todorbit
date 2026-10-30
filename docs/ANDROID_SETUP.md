# Android setup and acceptance

Source/parity: [Android architecture](ANDROID.md). This is development work;
building an APK does not establish production acceptance or authorize publishing.

## Toolchain and builds

Use Flutter 3.47.7 / Dart 3.13.5, JDK 21, Android API 36, build-tools 36.0.0,
NDK 28.2.13676358, the checked-in AGP/Kotlin versions and Gradle 9.3.1. The
wrapper uses the smaller binary distribution with its official SHA-256 pinned.
Kotlin incremental compilation is disabled: the retained Kotlin toolchain's
relocatable cache fails when the Windows checkout and Pub cache are on different
drives. This changes build caching only, not application behavior.
Set `JAVA_HOME` for the build process if the default `java` is an older JRE.
Install SDK tools with Android Studio/SDK Manager and accept the required SDK
licenses. `flutter doctor -v` must find the intended SDK and JDK.
Install **CMake 3.22.1** from SDK Manager for the JNI dependency. An existing
CMake/Ninja installation can instead be selected with `cmake.dir=<CMake root>`
in ignored `android/local.properties` and Ninja on `PATH`, following
[Android's CMake setup](https://developer.android.com/studio/projects/install-ndk).
The CMake version must match the version Gradle requests. This workstation uses
Visual Studio CMake 3.31.6/Ninja 1.12.1 plus an ignored task-local Gradle init
override of the JNI CMake version; CI installs SDK CMake 3.22.1 explicitly.
Installing SDK CMake 3.22.1 is the normal reproducible setup. Do not commit
machine-specific paths or change shared Pub package sources to configure it.
The helper accepts `-AndroidSdk <directory>` and `-GradleUserHome <directory>`
when the SDK/NDK and build cache belong on another disk. This development run
uses ignored `.buildlog/android-sdk` and `.buildlog/android-gradle-home` because
the system drive could not hold the NDK expansion. Those are local build
directories, not committed SDK binaries or product data.

```powershell
flutter pub get
./tools/build-android.ps1 -JavaHome '<JDK 21 directory>'
# Development artifact: build/app/outputs/flutter-apk/app-github-debug.apk
./tools/build-android.ps1 -JavaHome '<JDK 21 directory>' -Bundle
# Development bundle: build/app/outputs/bundle/githubDebug/app-github-debug.aab
flutter analyze --no-pub
flutter test --no-pub --concurrency=1
flutter test integration_test/android_workflow_test.dart --flavor github -d <isolated-emulator-id>
flutter drive --profile --flavor github --driver=test_driver/android_workflow_driver.dart --target=integration_test/android_workflow_test.dart -d <isolated-emulator-id>
python tools/verify-android-artifact.py build/app/outputs/flutter-apk/app-github-debug.apk
```

The APK includes arm64 and x86-64. Debug signing uses the local Android debug
keystore and is **not production signing**. The Android application ID is
`io.github.hik4.todorbit`; minimum API 26, target API 36, version 1.0.18/code 19.
Do not change identity or reuse a disposable key for public distribution.
`-Mode Profile` also uses development signing and enables profiling; it is not
a production release. The default `Debug` build supports hot reload.
The development artifacts do not include 32-bit ARM phones.

For production, place `android/key.properties` locally (ignored by Git), pointing
to a durable keystore outside the repository:

```properties
storeFile=C:/secure/todorbit-upload.jks
storePassword=<local secret>
keyAlias=<upload key alias>
keyPassword=<local secret>
```

Run `tools/build-android.ps1 -Mode Release` (or add `-Bundle`). Release builds
fail closed without signing configuration. In CI, materialize these values from
protected secrets, restrict artifact access, and remove temporary credentials
afterward. The Android validation workflow retains a development APK. The manual signed
candidate workflow requires protected credentials and validation, and retains
private artifacts only. No workflow publishes Android.

The alignment script checks every packaged ELF PT_LOAD segment and applicable
uncompressed APK ZIP offsets for 16 KiB alignment. It cannot establish runtime
compatibility. A 16 KiB-page Android emulator/device launch is a separate gate.
For a production AAB also verify `bundletool dump config --bundle=<aab>` reports
`PAGE_ALIGNMENT_16K`, then test the generated APK set. See
[Android's native compatibility guidance](https://developer.android.com/guide/practices/page-sizes).

## Google Drive and software updates

Android Google Drive is enabled by default; publisher package/certificate
registration is still required. See the exact [Cloud project/OAuth and portable
backup guide](ANDROID_GOOGLE_DRIVE.md). Ordinary users enter no credentials.
`-GoogleDrive` remains a compatible optional helper flag; `-DisableGoogleDrive`
explicitly produces an offline/local-backup-only build.

[Android Software Updates](ANDROID_UPDATES.md) documents channels, discovery,
verification, download/cancel/retry and Android installation permission.
[Production signing and candidate workflow](ANDROID_RELEASE.md) covers durable
keys, protected CI secrets, unpublished artifacts and debug-to-production recovery.
The GitHub flavor includes the installer; the Play flavor excludes it and opens
the official Play update flow. Add `--flavor github` to direct Flutter Android
build/run/test/drive commands. The PowerShell build helper selects GitHub by
default; `-Distribution play` selects the Play build.

## Install and exercise

Current Drive/updater development artifacts are in the ignored local directory
`.buildlog/android-update-deliverables/`. Use
**Todorbit-1.0.18-20-github-debug.apk** for a phone; its higher development version
code supports an in-place update from the earlier code-19 APK with the same
debug certificate. The AAB is not directly installable. Exact verification and
limitations are in [the acceptance record](ANDROID_ACCEPTANCE.md). The older
`android-deliverables` directory contains historical e881a12 artifacts.

On this workstation, from `D:\AI_Projects\life_manager`:

```powershell
$adb = "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe"
& $adb devices
$phone = 'YOUR_PHONE_SERIAL' # Use the USB phone's serial from the command above.
& $adb -s $phone install -r '.buildlog\android-update-deliverables\Todorbit-1.0.18-20-github-debug.apk'
& $adb -s $phone shell am start -n io.github.hik4.todorbit/.MainActivity
```

Enable Developer options/USB debugging and accept the phone's USB authorization
first. The phone must support 64-bit ARM and Android 8 or later. Alternatively,
transfer the APK by USB and open it in the phone's Files app, allowing that app
to install it when Android asks. This is development signing; a signing-mismatch
error must not be resolved by uninstalling an installation containing personal
data before a verified backup is exported. Google Drive is enabled in current
source; real connection requires the owner to register this package and signing
certificate using the OAuth guide above.

1. Enable Developer options and USB debugging on a test phone. Connect by USB,
   authorize the computer, and confirm `adb devices` lists the intended device.
2. `adb -s <device> install -r .buildlog/android-update-deliverables/Todorbit-1.0.18-20-github-debug.apk`.
   Launch Todorbit from the launcher. Do not uninstall a personal installation
   to resolve a signing mismatch; export a backup first and use a test device.
3. Add categories/projects from the drawer, create/edit tasks and events, check
   planned days versus deadlines, and mark work sessions separately from tasks.
   Exercise recurrence, subtasks, checklists, attachments, habits, goals, saved
   views, templates, timer recovery, Trash and approval-based Smart Reschedule.
4. To enable a reminder, choose a task/event notification time and grant Android
   notification permission. New tasks remain Off. Settings → notification
   permission and the **Android notification settings** entry control delivery.
   Use the latter after repeated permission denial or to change channel settings;
   permission status refreshes when returning to Todorbit.
   Alarms are inexact; Doze, force-stop and battery restrictions can delay them.
5. Long press the launcher → Widgets → **Todorbit Tasks** or **Todorbit Calendar**.
   Choose theme, opacity and task filter. Resize, reconfigure, restart the
   launcher/device and tap entries. Widget taps open editors; native code never
   completes a task or writes SQLite directly. App lock hides widget details.
6. Export a verified Windows `.sqlite` snapshot, transfer it to the phone, then
   Settings → Backups → Import SQLite. Review counts/replacement, confirm, and
   fully close/relaunch the app to apply the staged restore. Restore replaces
   records, never merges devices; a Before restore snapshot is retained. Use
   settings JSON transfer separately or the encrypted full Drive package for
   portable personalization. Managed attachment bytes are in SQLite snapshots;
   external Windows file/folder links need relinking on Android.
7. Enable a PIN you will remember, test wrong/correct PIN and device-authentication
   cancellation/success, and enable focus-loss locking over an open editor. Check
   both widgets hide details and the app-switcher preview is protected. App lock
   protects the interface; it does not encrypt the database.
8. Start the focus stopwatch, use Home, return, then test process/reboot recovery.
   A gap over two minutes requires review. Choose Keep elapsed time or Stop at
   last checkpoint explicitly; actual work must not complete or reschedule a task.
9. Export a backup before broader testing. Check text scaling/TalkBack, rotation,
   custom themes, attachments, battery/Doze behavior, and both launcher widgets'
   resize/reconfiguration. Record the phone model, Android version and observations.

Integration tests belong on a disposable emulator. The Flutter integration runner
uninstalls its test app afterward, including that test installation's private
data and launcher widgets. Do not run it against a personal phone/profile.

An app update signed by the same key retains private data. Android uninstall
removes private data, including local snapshots; keep a verified exported or
encrypted Drive backup. Android system Auto Backup is disabled so Keystore
credentials and device-specific privacy/configuration files are not silently
copied outside the app's reviewed backup flow.

## Manual/device acceptance still required

Record exact device/API/build and observed results. Host widget tests do not
establish these:

- API 26, API 33 notification permission denial/regrant, API 35/36 edge-to-edge,
  cutouts, gesture navigation, keyboard insets, RTL, text scale, rotation/tablet.
- Task/event/session links after cold launch, while locked and while editing;
  recurring occurrence identity; Back protection; process death immediately after
  saving; pending restore/migration approval and interrupted restore recovery.
- Reminder cancellation/duplicates, quiet hours, time/time-zone changes, reboot,
  Doze and force-stop/relaunch. No exact-alarm or permanent-service permission.
- Both real launcher widgets: configuration, resize, data changes, locked privacy,
  reboot/launcher restart and package upgrade. Projections are bounded to 500
  tasks/100 agenda items; alarms schedule the next 64, with bounded event-driven
  and 12-hour refresh jobs. A force-stopped app cannot promise background work.
- PIN retry limits, biometric/device credential availability and cancellation,
  app-switcher screenshots, notification previews and lock over an open editor.
- Real Google authorization/backup round trip, Play-less/offline devices, native
  16 KiB execution, release signing and upgrade compatibility. No physical-device
  acceptance may be claimed from emulator or Windows preview results.
