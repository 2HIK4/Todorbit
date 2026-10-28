# Android development acceptance — 2026-10-28

Status: installable development implementation verified on an isolated API 35
emulator. Production signing, real Google authorization and the physical-device
gates below remain outstanding. No Android release was published.

## Recovered state and continuation

The recovered checkout was clean on `feature/android-mobile` at `4de8dff`.
Previous implementation stages were committed:

- `8189c3d`: mobile shell, shared features and platform boundaries.
- `c4b0218`: editors, settings, reminders and account boundaries.
- `4de8dff`: native widgets/alarms/jobs/biometrics and packaging gates.

Most feature code already existed. The APK build was waiting on tool downloads;
Windows Release had succeeded. Android workflow, launcher, permission, document
picker and privacy acceptance were unfinished. Existing commits, Windows
releases, running personal Windows sessions and personal data were preserved.

Continuation fixes and checks:

- `7f11afc`: notification-permission recovery through Android settings, refresh
  permission on resume, readable widget statuses, overdue wording, asynchronous
  background-engine startup, Android restore guidance/build-version metadata,
  and CI path coverage. The integration fixture closes databases sequentially.
- `fea4b89`: preserve known pending inexact alarms through refresh/resume and
  midnight; remove delivered receipts before the 64-alarm limit; exclude changed,
  completed and stale occurrences. Arbitrary expired reminders in imported
  snapshots are not replayed. Riverpod disposes the integration controller once.
- `e881a12`: fix SAF export of Flutter temporary files. Flutter uses private
  `code_cache`; the native bridge now accepts it alongside private files/cache,
  retaining canonical, separator-bounded path checks. Android app-lock copy is
  platform appropriate.
- `e58f57c`: recurring event identity/quiet-hours regression coverage.

The normal APK/AAB and final Windows Release contain app source `e881a12`.
Later test/documentation changes do not change those product binaries.

## Product and parity

Todorbit `1.0.18+19`, schema 22, package `io.github.hik4.todorbit`.
Minimum Android 8/API 26; target/compile Android 16/API 36. Development artifacts
include arm64-v8a and x86-64; 32-bit ARM is outside these artifacts.

The repository, migrations, recurrence, scheduling, controller, snapshot codec,
themes and productivity tools are shared with Windows. Android has separate
navigation/editors, private storage, SAF, Google authorization, biometric/device
credential bridge, alarms/jobs, stable links and actual RemoteViews widgets.

The [feature-by-feature status matrix](ANDROID.md) classifies Complete, Partial,
Blocked and Not Applicable with evidence and limits. No supported feature in
that inventory is Not Started. [Setup/signing/OAuth/phone installation](ANDROID_SETUP.md)
and the [future synchronization proposal](FUTURE_CROSS_DEVICE_SYNC.md) cover the
remaining dependencies. Drive remains optional snapshot backup, not sync.

## Automated and build evidence

| Check | Result | Local evidence |
| --- | --- | --- |
| Final full shared Flutter suite | **385 pass / one intentional native-service skip** | `.buildlog/android-installable-full-tests.log` |
| Final analysis of all lib/test/integration_test/test_driver sources | **No issues** | `.buildlog/android-installable-analysis.log` |
| Android planner/privacy policy tests | **10 pass**, included in full suite | `test/android_platform_test.dart` |
| Focused mobile/backup/privacy continuation regression | **23 pass** | `.buildlog/android-export-fix-ui-tests-clean.log` |
| Android workflow, API 35 x86-64 | **One end-to-end test passes**: create/edit/complete, event, persistence, safe restore | `.buildlog/android-verified-workflow.log` |
| Normal Android debug APK at e881a12 | **Build succeeds**, 210.6 s | `.buildlog/android-installable-apk.log` |
| Android debug AAB at e881a12 | **Build succeeds**, 51.7 s | `.buildlog/android-installable-aab.log` |
| Native ELF/applicable APK ZIP alignment and complete packaged ABIs | **Seven native libraries pass** in each artifact | `tools/verify-android-artifact.py` |
| APK/AAB signatures | **Verified**, local development certificate | `.buildlog/android-installable-apk-signature.log`, `android-installable-aab-signature.log` |
| AAB native-library configuration | **PAGE_ALIGNMENT_16K**, uncompressed native libraries enabled | `.buildlog/android-installable-bundle-config.log` |
| Windows Release at e881a12, isolated checkout | **Build succeeds**, 118.8 s | `.buildlog/android-installable-windows-release.log` |
| Packaged Windows companion self-test at e881a12 | **Exit 0**, persistence self-test passes | `.buildlog/android-installable-native-selftest.log` |
| Isolated Windows mobile preview | Launch/render/hot reload observed | `.buildlog/android-ui-profile` |
| Android live diagnostics | Hot reload succeeds; connected runtime reports no errors | Continuation tool session |

The full suite includes mobile phone/tablet, large text, RTL/dark layouts, editor
Back protection, mobile preferences, account-boundary tests, recurrence, migrations
and snapshots transferred between distinct disposable profiles in both directions.
Native Windows self-test has isolated APPDATA/LOCALAPPDATA; it does not establish
physical Windows DPI/input behavior. No Windows native source changed.

The workflow test ran before the final native export fix; final native behavior
was exercised using the normal e881a12 APK below. The integration test runner
uninstalls its temporary app afterward; it was never run on a personal phone.
An earlier duplicate-disposal fixture failure and a mistaken test-path invocation
were corrected and the affected commands rerun successfully. A prior Windows
Flutter Driver tap timeout is not counted as a successful interaction.

## Observed Android behavior

All observations use the disposable Google Play API 35 x86-64 emulator
`emulator-5580`, AVD `TodorbitAndroidTest`, with no personal account/profile.

- Today/task/event creation, safe Back/Keep editing, edit/complete/persistence and
  cold task URI handling work. Planned days and deadlines remain separate.
- Both real launcher widgets were added/configured. Tasks initially used
  Dark/All/95%; Calendar uses System/95%. Reopening Tasks configuration from the
  launcher and applying a changed opacity persisted 79%. Actual task/event links
  open their corresponding editors. Both hide details whenever app lock is
  enabled, including after unlock. Package update retained both widget
  configurations and task data.
- Notification permission was denied twice and re-enabled through the in-app
  Android notification-settings route. The app refreshed to Allowed on return.
- Task **and** event reminders delivered in the background. The native ledger
  contains two distinct receipts, once each; the subsequent plan contains no
  pending alarms. The task notification opens its correct editor.
- The event notification preserves an open unsaved task draft. The Back guard
  requires Keep editing or explicit discard; after discard, the queued event
  opens correctly. No draft was silently saved, discarded or replaced.
- App-lock setup, persistence through package update/cold launch, incorrect PIN,
  correct PIN, device-authentication cancellation and successful Android device
  credential authentication work. Focus-loss locking covers an already-open
  editor and excludes its accessibility content. FLAG_SECURE blocks app capture.
  This does not establish physical fingerprint/face enrollment.
- SAF exported a verified Android SQLite snapshot to Downloads. The actual file
  opened on Windows with integrity OK, schema 22 and the expected task UUID/title.
- SAF imported a Windows snapshot, previewed one task/event/category/project,
  required replacement confirmation, and staged it without replacing active data.
  Closing from Recent apps and reopening applied it with the original identities.
  The retained Before Restore file passes integrity/foreign-key checks and
  contains the previous task UUID/title.
- A managed PDF was attached through SAF and rendered by Android's PDF viewer via
  a private FileProvider URI with read permission. External Windows paths remain
  explicitly unavailable until relinked.
- A forced cold background job completed via jobFinished in about four seconds
  while the app was not foregrounded. No permanent foreground service is used.
- Timer start and short process termination/relaunch retain elapsed state.
  After reboot and a gap over two minutes, the timer requires explicit review.
  Stop at last checkpoint retains the confirmed 1:33 work interval without
  counting the uncertain gap or completing the task. Both widget configurations
  and the two delivered reminder receipts also survived reboot.

Evidence includes ignored `.buildlog/android-task-event-notifications.png`,
`android-reminder-delivery-state.json`, `android-notification-preserved-draft.xml`,
`android-lock-over-editor.xml`, `android-managed-pdf-open.png`,
`android-before-restore-verification.log`, `android-headless-job-after.txt`,
`android-timer-reboot-review.xml`, `android-timer-checkpoint-stopped.xml` and
`android-final-device-state.json`.

## Installable artifacts

Directory: `.buildlog/android-deliverables/` (ignored, local only).

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| `Todorbit-1.0.18-19-debug.apk` | 185689710 | `39eff169f16a4dc861a723f4fd710c3471fa0fbf360d41d8352b75c324cc283d` |
| `Todorbit-1.0.18-19-debug.aab` | 78424877 | `7afa700d949c92e77c55ba14557f93e2bbd5498829550caf62cbe75ccf4d246b` |

`SHA256SUMS.txt` is alongside them. APK signer certificate SHA-256:
`9144c2df0aa461641f8570d62f880ee9e481c272a80673089a6799d111c9bf73`.
These are debug/development-signed artifacts; no production key was invented.
Install the APK on a phone. The AAB is not directly installable.

## Remaining external and device acceptance

- **Google Drive: blocked for real acceptance.** The owner must register package
  and signing certificate in the existing Google Cloud project, then enable the
  compile flag. Real consent/upload/read-back/restore and wrong-account/revocation
  tests have not occurred. Mock/codec/account tests are not real authentication.
- **Production signing: blocked.** Owner's durable keystore is required. Release
  builds fail closed without local signing configuration. Development signing
  does not establish a public upgrade identity.
- Physical phones, representative API 26/33/36, fingerprint/face hardware, TalkBack,
  cutouts, OEM launchers/battery behavior, Doze, DST/time-zone changes, large-data
  performance and actual 16 KiB-page execution remain manual gates. Native
  alignment does not establish runtime behavior on a 16 KiB-page device.
- Widget resize handles appeared, but scripted dragging did not confirm a bounds
  change. Resize/reconfiguration breadth and launcher/OEM lifecycle coverage remain
  manual beyond the scoped observations above. Remote Windows/Linux CI is
  configured; this branch has not been pushed or remotely executed.
- The software emulator showed System UI ANRs during initial setup and reboot;
  selecting Wait recovered the UI. Tests use 720×1600/280 dpi with animations
  disabled. Startup under host memory pressure was slow, with some historical
  job binding timeouts followed by successful retries. This is not physical-device
  performance acceptance; phone startup/battery profiling remains required.
- No public Windows release/tag was changed, no Android/Play release was
  published, and no signing credential, OAuth secret or telemetry was added.
