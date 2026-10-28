# Android development acceptance — 2026-10-28

Status: implementation and device acceptance in progress. This report separates
observed checks from remaining release gates; no Android publication is authorized.

## Product and source

- Branch: `feature/android-mobile`; shared/UI milestones `8189c3d`, `c4b0218`.
- Todorbit `1.0.18+19`, SQLite schema 22, package `io.github.hik4.todorbit`.
- Minimum Android 8/API 26; target/compile Android 16/API 36.
- Shared repository, migrations, recurrence, controller, snapshot format, themes,
  and productivity tools. Android-specific shell, private storage, SAF, Google
  authorization, biometric bridge, alarms/jobs, deep links and RemoteViews widgets.
- [Feature inventory/parity](ANDROID.md), [setup, signing, OAuth and installation](ANDROID_SETUP.md),
  [future synchronization proposal](FUTURE_CROSS_DEVICE_SYNC.md).

## Observed automated evidence

| Check | Result | Local evidence |
| --- | --- | --- |
| Shared Flutter suite at `c4b0218` | 380 pass, one intentional native-service skip | `.buildlog/android-final-tests.log` |
| Shared/static analysis at `c4b0218` | No issues | `.buildlog/android-analysis.log` |
| Android surface planner and immediate privacy policy | Six tests pass | `.buildlog/android-surface-tests.log` |
| Windows Release at `c4b0218` | Build succeeds in isolated checkout | `.buildlog/android-windows-isolated-release.log` |
| Packaged Windows widget self-test | Exit 0; persistence self-test passes | `.buildlog/android-native-selftest-profile` |
| Windows mobile preview | Isolated profile launches, screenshot inspected, hot reload succeeds | `.buildlog/android-ui-profile` |
| Native Android compile | `compileDebugKotlin` succeeds | `.buildlog/android-native-compile.log` |

The compile-only Android check excludes engine JARs containing native binaries
from the Kotlin compile classpath. It checks Kotlin symbols and code, and does
not establish APK packaging or native runtime acceptance. Those require a real
build and emulator/device execution. A previous Windows Flutter Driver tap timed
out; it is not evidence of successful live interaction.

The full suite includes mobile phone/tablet, large-text/RTL/dark layouts, editor
Back protection, mobile preferences, account-boundary checks, recurrence and
migrations, plus snapshot transfer between two isolated profiles in both directions.
No personal profile was reset or opened for these checks. Existing Windows app
and widget sessions were preserved while Release was built in a separate worktree.

## Android artifacts and device checks

An x86-64 profile APK was packaged and installed, with its debug certificate
verified using `apksigner`; minimum/target/version/package metadata matched the
configuration above. All five native libraries passed ELF and APK ZIP alignment,
and every packaged ABI had a Flutter engine. The auxiliary profile build was
stopped after packaging while downloading Android lint tooling; a complete profile
Gradle success is not claimed. The final debug APK/AAB and workflow are pending.

Observed on the isolated emulator: Today renders; task creation/save; Android
Back prompts to discard edits; Keep editing retains the title; force-stop and
cold relaunch retain the task; a cold task URI opens the correct editor; and a
calendar event can be created and appears in its selected day's agenda. These
are actual Android UI checks, separate from host widget tests.

Test device is the isolated API 35 x86-64 Google Play emulator `emulator-5580`;
it is not a physical Android phone. The initial 1080×2400 software-rendered emulator
showed a System UI ANR. Interaction recovered after reducing it to 720×1600 at
280 dpi and disabling system animations, retaining the same logical phone width.
Observed cold Activity start waits of about 5.4–9.3 seconds under this host load
are not physical-device performance measurements. The
task-local SDK, NDK and Gradle cache are ignored under `.buildlog` on D:.
Slow Flutter engine downloads were resumed in ranges and verified against the
original Google Storage size/MD5 before entering a task-local Maven cache.

## External and manual release gates

- Real Google Drive authorization requires the owner to register the Android
  package and signing certificate in the existing Google Cloud project. Code and
  mocked account/refresh safeguards are tested; real consent/upload/restore is
  not established by a mock. Exact configuration is in the setup guide.
- Production APK/AAB signing needs the owner's durable keystore. Release builds
  fail closed without `android/key.properties`; development signing does not
  establish a public signing identity or upgrade compatibility for production.
- Physical-device battery/Doze/reboot, accessibility/TalkBack, cutouts, OEM launcher
  behavior, biometric enrollment and representative older/current API coverage
  need the device checklist in the setup guide.
- Native ELF/ZIP alignment and actual execution on a 16 KiB-page device are
  separate checks; passing one must not be reported as passing the other.
- No public release, signing key, OAuth secret, account authentication or telemetry
  has been introduced or published by this task.
