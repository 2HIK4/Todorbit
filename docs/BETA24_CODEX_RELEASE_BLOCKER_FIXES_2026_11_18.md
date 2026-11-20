# Beta 24 release-blocker implementation receipt

- **Branch** `fix/todorbit-beta24-release-blockers`
- **Base** `253bc54eb74300505793cf0a6e5328a3858f23da`
- **Candidate** `1.0.19-beta.24+47`
- **Checked** 2026-11-18 (UTC+03:00), Windows 11 and an isolated Android API 35 emulator
- **Source and test tree before receipt updates** `53f93fb84ca934c058b2ab7da1ffa05b7cc9babe`

| Issue | Cause | Repair and regression evidence |
| --- | --- | --- |
| P1-01 Sync | Startup could capture the legacy preference deletion, advance the origin sequence, and then erase its journal row and supersede unrelated batches. The outgoing mapper could also rewrite a retained value. | Opening SQLite makes no compatibility writes. Device presentation reads from the local profile. New enrollment excludes the standalone legacy key and normal preference writes use the current allowlist. Exchange preserves exact staged bytes and rejects incompatible retained content before upload. Tests reopen an enrolled database twice, compare journal, heads, groups and clocks, verify exact-byte retries, and apply an original historical envelope and its dependent task revision on a peer. |
| P1-02 Android inbox | Dart and Kotlin independently loaded and rewrote one manifest. Cleanup could race staging, and copy-over fallback could destroy a valid index. | Both activities and the Flutter storage channel use one native worker. Each file is flushed and renamed before a checked atomic manifest publication. Deletion publishes before unlinking. Recovery uses a valid manifest to collect recognized staging files and orphans. Native checks exercise queued imports, deletion, cleanup, duplicates, failed publication, interrupted state, and multiple streams. A host integration test verifies the independent task attachment after inbox deletion. |
| P1-03 Workspace | Sidebar search changed selection before it checked the dirty editor. Calendar Escape and focus-timer paths could also bypass the Workspace guard. | Workspace waits on the mounted editor and prevents competing transitions. Task and event editors share the Save, Discard and Keep editing decision. Save uses the existing persistence path and returns success before routing. Widget checks exercise task and event selection, both searches, Escape, timer entry, rapid navigation and an injected SQLite save failure in both presentation modes. |
| P1-04 Smart Reschedule | Apply checked event template timestamps, which can be outside the interval where an occurrence overlaps. | Apply projects fixed and recurring occurrences in the writer transaction, respects cancelled and moved exceptions, and checks existing sessions. Tests cover stale one-off events, stale work sessions, out-of-range recurring masters, moved-in and cancelled/moved-out exceptions, atomic rejection, successful Apply and Undo. |
| Related Sync and Calendar | Read refresh was the only route to a change signal, and a changed mounted Calendar date only updated selection. | Controller mutations signal Sync on commit, while read refresh signals only when it materializes recurring work. The mounted Calendar defers an external date while dragging and loads the requested recurrence window when the interaction ends. |

The Android worker uses checked file and directory synchronization and rename.
The framework's AtomicFile implementation logs commit errors, which prevents
the caller from relying on its return to acknowledge a durable import.
[Android framework AtomicFile](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/main/core/java/android/util/AtomicFile.java).

## Sync compatibility boundary

Beta 23's tagged validator rejects the standalone `detailPresentation` key and
expects a normalized portable customization value. Current writes omit the key
and nested field from exchange. Beta 24 can retain and apply an authenticated
historical preference envelope as part of its original sequence without using
it to choose the local editor presentation.

An incompatible retained revision may already have been seen by a peer.
A missing batch link is insufficient proof that it never left the profile.
Earlier code and history migrations could detach or supersede stages. Beta 24
halts exchange when it encounters an incompatible pending revision or envelope.
It preserves the exact bytes, revision IDs, links, clocks, conflict history and
later offline work. A compatible staged upload still retries byte for byte.
The peer test acknowledges the historical envelope only with a synthetic
verified receipt for those original bytes. Production reconciliation requires a separate reviewed recovery.
Already published incompatible content can still block Beta 23.
Shared database downgrade with a legacy row present requires separate acceptance.
Profiles opened by the earlier destructive candidate may already have gaps and
require review with their retained snapshots.

Schema 29 and WAL `synchronous=FULL` are verified by the enrolled-profile restart
test. The patch leaves dependency manifests, package version and cloud workspaces
intact.

## Verification

Host commands used disposable `APPDATA` and `LOCALAPPDATA` under the worktree's
ignored `.buildlog/beta24-codex` directory. Flutter tests ran serially. Native
tests used the explicitly named `TodorbitBeta24Codex` emulator and a unique
app-cache fixture. Detailed logs stay in that ignored directory.

- **Final host coverage** 187 distinct tests passed, 0 failed, 0 skipped.
- **Native Android** 4 passed, 0 failed.
- **Original-candidate probes** 0 passed, 4 expected failures.

| Host invocation | Result and reason |
| --- | --- |
| `flutter pub get --enforce-lockfile` | Pinned packages resolved. The final Windows plugin link step returned an error because local symlink support is disabled. The package configuration supported host tests and Android Gradle. The dependency files remained at the base revisions. |
| Initial `flutter test --no-pub --concurrency=1 --reporter expanded` with `sync_exchange_repository`, `prompt4_smart_reschedule`, `workspace_draft_safety` and `prompt8_codex_fixes` | 69 passed and 4 failed. Fixed stale presentation fixtures and search locators and expanded the Calendar regression. |
| Same serial Flutter test flags, broad checkpoint | **181 passed**, 0 failed. Suites `workspace_draft_safety`, `beta24_calendar_sync`, `prompt8_codex_fixes`, `prompt4_smart_reschedule`, `sync_exchange_repository`, `sync_apply_repository`, `sync_journal`, `database_initialization`, `event_recurrence`, `shared_inbox_store`, `shared_inbox_screen`, `shared_inbox_task_integration` and `workspace`. Log `checkpoint-tests.log`. |
| Same serial Flutter test flags, navigation follow-up | `workspace_draft_safety`, `prompt8_codex_fixes`, `mobile_editors` and `widget_release_audit`. 46 passed and 1 fixture failed because its locator matched the search query field as well as the result. The exact affected test passed **1/1** with the result row locator. This run verifies the final event guard and injected persistence failures in place of the preliminary Workspace evidence. |
| Same serial Flutter test flags on an archive of `253bc54`, filtered to the four new probes | First attempt needed the local generated package graph. The retry reproduced **four expected failures** for sidebar route mutation, recurring overlap acceptance, external Calendar date changing mid-drag, and Sync device sequence advancing from 3 to 4 during reopen. The archived Sync test uses a generic exception expectation after the history assertion because the baseline lacks the new exception class. The baseline fails at the history assertion. Log `baseline-probe-retry.log`. |
| `flutter analyze --no-pub` | Full analysis reported zero issues in both runs, including the final locator. |
| `dart format --output=none --set-exit-if-changed` on 20 touched Dart files and `git diff --cached --check` | Passed. The legacy Prompt 8 test file retains inherited formatting outside the edited hunks to avoid unrelated reformatting. |

| Android invocation | Result |
| --- | --- |
| `avdmanager create avd` for `TodorbitBeta24Codex` and emulator acceleration check | Fresh x86-64 Android 35 AVD, WHPX available. |
| `gradlew.bat :app:assembleGithubDebug :app:assembleGithubDebugAndroidTest` | Checkout lacked the ignored wrapper executable. Used the installed Gradle 9.3.1 distribution pinned by the project. |
| Gradle 9.3.1 `:app:assembleGithubDebug :app:assembleGithubDebugAndroidTest -Ptarget-platform=android-x64 --max-workers=2`, JDK 21/API 36, 3 GB heap | First compilation identified an unavailable `OsConstants.O_DIRECTORY`. Replaced it with the supported read-only directory open. Retry compiled the app and instrumentation APKs successfully. |
| `adb -s emulator-5586 shell am instrument -w -r -e isolated true -e sharedInbox true io.github.hik4.todorbit.test/io.github.hik4.todorbit.WidgetRenderInstrumentation` | Initial ADB readiness check found the device offline. Retried after verified boot on the same isolated AVD. Native storage checks **4 passed, 0 failed**. App APK SHA-256 `58e7982e650092a8e858175d4fcf6d675409378fbe2d6ddd4c79215704a1ba47`. Test APK SHA-256 `c302f72fba80bc8c1fd76d49087af4b361bc1a9b2e0a0ee4d87889c5081d396a`. This verifies the Kotlin changes. |
| DTD discovery and `flutter attach` | The first attach rejected the `--no-pub` option. Retrying on emulator-5586 hit a DevFS disconnect. Restarted the same isolated AVD on emulator-5564 with a supported port and attached successfully. Hot reload reassembled the app in 5.7 s and hot restart completed in 15.8 s. |

Physical Android sharing with provider grants, cold-start delivery, abrupt
process termination and the Flutter channel interaction remain acceptance items.
The native recovery fixture reopens storage from the equivalent interrupted
on-disk states. Hardware power-cut behavior, physical Windows
keyboard and focus, exact release builds and updates, real Drive authorization,
and the Android 16 KiB runtime gate remain open.

## Gemini integration

Review this branch locally and confirm that the release branch still points to
the expected candidate. In the Gemini worktree, apply the checkpoint when ready
with `git cherry-pick fix/todorbit-beta24-release-blockers`, or use the exact hash
reported in the handoff. Repeat exact-candidate release acceptance after
integration. Keep affected legacy profiles and their recovery snapshots intact
if the Sync compatibility stop appears. Stable and Gemini's checkout were left
untouched. No release, push or tag was made.
