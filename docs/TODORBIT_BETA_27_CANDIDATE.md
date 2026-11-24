# Todorbit Beta 27 candidate acceptance

`1.0.19-beta.27+50`, SQLite Schema 29, on `feature/todorbit-ui-redesign-2`.
The candidate is unpublished. Stable and previous release assets retain their
existing versions. The [release notes](TODORBIT_BETA_27_RELEASE_NOTES.md) describe
the redesign, customization and supported install paths.

## Exact source and package gates

Candidate `7ede8890cc1216cf70b6dfa1454cb1ab45b53cd2` builds on final redesign
acceptance `2f4c18a`. The first versioned source `50f5652` changed version
metadata and the native Android splash. The follow-up changes only Android
integration test scrolling. The complete Calendar, SQLite reopen and
snapshot-restore assertions remain in the journey.

| Gate | Evidence |
| --- | --- |
| Windows full validation and packaging | **Passed.** The [exact candidate](https://github.com/2HIK4/Todorbit/actions/runs/45388886278) passed full analysis, 1,238 tests with 9 opt-in skips, 39 architecture checks, documentation checks, OAuth configuration checks, CRT checks, native writer, hidden background barriers, packaged widget self-test and Inno Setup compilation. |
| Android analysis, platform checks and emulator integration | **Passed.** Analysis, 76 focused tests, development APK integrity and both emulator integrations, including native update and backup/restore, passed on the [exact candidate](https://github.com/2HIK4/Todorbit/actions/runs/45388885387). The [first run](https://github.com/2HIK4/Todorbit/actions/runs/45385900187) hit the bottom navigation because the Calendar event row was below the viewport. |
| Production Android signing | **Blocked.** The production JKS exists. Its ignored `android/key.properties` was absent from the original checkout, this worktree and the accessible prior release worktrees and local release directories. The protected signing workflow could not be dispatched. |
| Official API 36 16 KiB runtime and packaged Android upgrade | **Blocked on production signing.** Stage the actual candidate and previous production-signed APK by asset ID and checksum. Verify page size, in-place upgrade, profile and task persistence, reopen, foreground return and native integration. |
| Experimental updater discovery and anonymous asset verification | **Pending publication.** Exact-candidate tests passed for Stable and Experimental channel selection, version and platform compatibility, download integrity and updater handoff. The previous published Beta 25 APK matches its update metadata digest. |

### Verified Windows downloads

The [exact-source Actions artifact](https://github.com/2HIK4/Todorbit/actions/runs/45388886278/artifacts/14920097148)
contains both Windows packages, both `.sha256` sidecars and `SHA256SUMS.txt`.
The downloaded files are under `.buildlog/beta27/windows-production-candidate/`.

| Package | Bytes | SHA-256 |
| --- | ---: | --- |
| `Todorbit-1.0.19-beta.27-win-x64-setup.exe` | 48,076,142 | `5254574e55ba3a61732c1673fb512524f131792cf002b97e3e257222af5c3c98` |
| `Todorbit-1.0.19-beta.27-win-x64-portable.zip` | 65,492,956 | `066a9ba8f1eafa360a543d5dcd26a7688564b430c9e379f3f2f5982dbe47d6d8` |

Both file hashes match the sidecars and manifest. All 43 portable entries
passed archive integrity and private-file checks. The runner and AOT hashes
match the production Drive build receipt, with the private test flag off.
The ZIP also contains the companion and required CRT DLLs. PE resources on
the runner, companion and installer report numeric version `1.0.19.50`.
The Windows installer remains unsigned under the existing policy.

### Android signing handoff

The previous published APK has certificate SHA-256
`00226dad75ac907ac51c86df2c5011f0b6e2ce8291994103975f11a8eb574a99`.
Restore the approved ignored `android/key.properties` in the release worktree
with `storeFile` pointing at the existing production JKS, `keyAlias=todorbit`
and the owner-provisioned `storePassword` and `keyPassword`. Follow the local
configuration example and package checks in [Android release](ANDROID_RELEASE.md).
Compare every candidate APK certificate with the published fingerprint before
staging. Keep the keystore and signing properties local. Do not uninstall the
previous beta to work around a certificate mismatch.

## Android Release startup and visuals

An exact archive of `50f5652` was built with Flutter 3.47.7 and Dart 3.13.5.
Its packaged inputs match `7ede889`. The non-debuggable APK used an existing
disposable signing fixture and disabled Drive. It was tested offline on a
disposable Android API 35 x86-64 emulator with 4 KiB pages, 2 guest cores,
2 GiB configured guest RAM and software rendering. The APK and all eight
native libraries passed static alignment checks. This artifact is for local
verification only.

| Launch | Android runtime measurement |
| --- | --- |
| First launch after install | 20.637 s to native `Displayed`. The `am start -W` waiter returned a timeout at 14.174 s and the app subsequently drew Today. |
| Return from Home with process retained | 0.722 s waiter time. Android did not report a fresh draw duration. |
| Three cold process reopens | 6.356 s, 3.325 s and 3.254 s to draw. |
| Cold reopen in light system theme | 3.671 s to draw, sampled for the native splash. |

Host snapshots recorded 42% CPU and 0.73 GiB free RAM before the first run,
and 20% CPU and 0.54 GiB free RAM before the reopens. No local build ran during
the timing loop. Use these as measurements of the fixture environment. The
previous Debug runs and the official production 16 KiB gate have separate
receipts.

The emulator showed the same neutral `#15191C` native splash in both system
themes, with the complete orbit and a normal handoff to Flutter. Calendar and
Archive/Trash use the expected Material glyphs in the real Release app. A
synthetic task was moved to Trash, restored, and present after a cold process
reopen. The Month agenda displayed it under its planned date.
The older placeholder squares and debug banner did not reproduce in those
renders. Local evidence is under `.buildlog/beta27/emulator/` and
`Documents/Codex/Todorbit-beta27-renders/`:

- `android-release-splash-dark.png` and `android-release-splash-light.png`
- `calendar-release.png` and `calendar-release-populated.png`
- `archive-release.png` and `trash-release-populated.png`
- `today-release-light.png`

## Data preservation and manual acceptance

The [final integration receipt](UI_REDESIGN_FINAL_ACCEPTANCE.md) demonstrates
Beta 26 to redesign portable reopen in the normal Windows session. The
disposable profile retained Schema 29 integrity, a synthetic task and a
device-local preference. The Beta 27 Windows product changes affect version
metadata. Use a separate Windows test account or machine for the registered
installer journey with the established AppId. Windows Sandbox is excluded.

1. In the isolated Windows account, install the previous beta, create a task
   and event, change a device-local preference, and export and verify a
   backup. Exit Todorbit and its companion. Apply Beta 27 Setup over the same
   installation, restart, and verify the same records, preference, widget
   and installed update target. Test the portable ZIP separately with its own
   disposable profile and verify that its updater selects the portable ZIP.
2. Once production packages are available, update the prior Android beta in
   place. Check existing tasks, preferences and the launcher widget. Create
   and edit a task at enlarged font size, put it on Calendar, resume a Focus
   timer after returning from Home and verify reopen. Try the widget on the
   phone's launcher and confirm notifications as permitted by device settings.
3. On Windows, narrow the window and use 150% text. Tab through Today, task
   editing, Calendar and Settings. Check focus visibility, draft recovery,
   tooltips and both themes. Use Narrator or TalkBack on the target device for
   assistive acceptance. Use separate synthetic accounts for any two-client
   Drive recovery test with explicit authorization.

Real-device input, assistive output and two-client Drive testing have separate
acceptance records. The production signer, exact candidate CI, production
packages and official 16 KiB runtime remain mandatory publication gates.
