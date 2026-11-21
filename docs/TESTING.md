# Testing and verification

Run commands from the repository root in PowerShell. Resolve dependencies with
`flutter pub get` after checkout/dependency changes. `--no-pub` below assumes that
has succeeded. Toolchain/profile setup lives in [Development](DEVELOPMENT.md).

## Choose checks by changed boundary

Before testing, read the repository instructions and relevant feature guidance,
identify the affected functionality, then inspect its latest verification receipts
and CI results. Check the command/assertions, validated commit or artifact hash,
result, covered behavior and environment. A matching test name alone is not
evidence that a previous pass applies.

Reuse a pass when the relevant implementation, dependencies/behavior, assertions
and equivalent environment are unchanged, and release policy permits reuse.
Explain any invalidation before rerunning. Required exact-source release CI still
applies; an existing pass on that exact candidate satisfies it. Documentation-only
follow-ups do not invalidate packaged runtime evidence. Do not rebuild unchanged
artifacts or repeat local full suites merely to refresh a receipt.

| Verification level | Scope | Execution policy |
| --- | --- | --- |
| **Level 1: Fast** | Small text, cosmetic, layout or UI edits; focused unit/widget tests; relevant static analysis (`flutter analyze --no-pub <paths>`) | Run immediately after relevant edits during coding. |
| **Level 2: Critical** | Data safety, SQLite persistence, schema migrations, CAS revision tokens, sync exchange/journals, encryption, backup/restore, recurrence math, alarms, and undo/redo stacks | Run the smallest tests covering the changed critical boundary immediately; **never deferred**. Reuse matching valid passes; unrelated UI/docs changes do not require every critical suite. Unverified critical code cannot be marked complete. |
| **Level 3: Deferred Regression** | Broad serial Flutter test suites, multi-module integration, cross-platform host regression, and release tooling unit tests | Batched periodically or triggered on-demand; record requirements in [Deferred verification](DEFERRED_VERIFICATION.md). |
| **Level 4: Release Acceptance** | Packaging (Release C++ build, Inno Setup installer, signed APK), isolated Windows Sandbox upgrades, physical display DPI checks, Android 16 KiB runtime, and real Google OAuth | Mandatory before publication; record requirements in [Deferred verification](DEFERRED_VERIFICATION.md). Never treat Levels 1â€“3 as release readiness. |

These correspond to risk tiers. The local helper modes remain Quick/Feature/Full.
Critical selects explicit affected checks; Release adds the required CI, artifact
and platform acceptance gates. Full Flutter suites need a concrete integration or
release reason, not an ordinary UI edit. Record unexecuted Level 3 and Level 4 gates in
[Deferred verification](DEFERRED_VERIFICATION.md). Diagnose a failed environment before
retrying it; change one relevant condition or collect new diagnostic evidence.

### Module test matrix

Use these examples to select assertions for the actual changed boundary. A row
is not a command to run every listed suite. The authoritative group catalog is
`tools/dev/features.json`; include adjacent safety tests when a caller or data
invariant changes. Reuse valid four-fingerprint evidence before any invocation.

| Module / Directory | Level 1 (Fast) Tests | Level 2 (Critical) Tests |
|---|---|---|
| **Tasks & Editor** (`lib/features/workspace/`, `lib/domain/models.dart`) | `test/workspace_test.dart`, `test/task_editor_schedule_layout_test.dart` | `test/repository_test.dart`, `test/task_revision_concurrency_test.dart` |
| **Calendar & Events** (`lib/features/calendar/`, `lib/domain/recurrence.dart`) | `test/calendar_test.dart`, `test/calendar_improvements_test.dart`, `test/calendar_card_contrast_test.dart` | `test/event_recurrence_test.dart`, `test/calendar_event_move_recurrence_test.dart`, `test/calendar_series_integrity_review_test.dart`, `test/calendar_undo_redo_test.dart` |
| **Database & Migrations** (`lib/data/app_database.dart`, `lib/data/migration_gate.dart`) | `test/repository_test.dart` | `test/database_initialization_test.dart`, `test/migration_gate_test.dart`, `test/backup_service_test.dart` |
| **Sync & Encryption** (`lib/data/sync*`, `lib/domain/sync/`, `lib/data/cloud/`) | `test/sync_journal_test.dart`, `test/cloud/sync_batch_codec_test.dart` | `test/sync_apply_repository_test.dart`, `test/sync_exchange_schema_test.dart`, `test/sync_exchange_repository_test.dart`, `test/cloud/google_drive_changes_test.dart` |
| **Backup & Cloud Transfer** (`lib/data/backup_service.dart`, `lib/data/cloud/cloud_backup*`) | `test/import_export_test.dart`, `test/settings_transfer_test.dart` | `test/backup_service_test.dart`, `test/cross_platform_backup_test.dart`, `test/cloud/cloud_backup_test.dart` |
| **Alarms & Notifications** (`lib/data/notification*`, `lib/data/alarm*`, `lib/domain/alarms*`) | `test/notification_auto_dismiss_test.dart`, `test/alarm_field_test.dart` | `test/alarm_test.dart`, `test/alarm_migration_test.dart`, `test/notification_repository_test.dart` |
| **Settings & Preferences** (`lib/features/settings/`, `lib/data/profile_fingerprint.dart`) | `test/appearance_preference_store_test.dart`, `test/theme_customization_test.dart` | `test/settings_transfer_test.dart`, `test/profile_isolation_test.dart` |
| **Mobile & Android Shell** (`lib/features/mobile/`, `lib/platform/android/`) | `test/mobile_workspace_test.dart`, `test/mobile_editors_test.dart` | `test/android_platform_test.dart`, `test/android_widget_action_test.dart`, `test/cross_platform_backup_test.dart` |
| **Windows Desktop Widgets** (`lib/features/widget/`, `experiments/widget-shell-probe/`) | `test/widget_configuration_test.dart`, `test/widget_settings_page_test.dart` | `test/native_widget_service_test.dart`, native companion `--self-test` |


## Verification ledger

Start with the persistent [test run ledger](TEST_RUN_LEDGER.md), then follow its
relevant task receipt. Before **any** test, identify changed behavior and its
smallest covering assertion, compare prior source/dependency/configuration/
environment fingerprints, and reuse an equivalent valid pass. A new task, a
documentation edit, or an unrelated platform edit does not justify rerunning.
Prefer one final focused check after code stabilizes. Log necessary debugging
reruns with the change or new evidence that invalidated the earlier result.

New receipts must be linked in the persistent ledger and include local date/time
with UTC offset, task, commit plus dirty-source fingerprint, affected paths,
exact command, scope/purpose, Passed/Failed/Blocked/Skipped, necessity/rerun reason,
and prior evidence or concise output location. Record meaningful skips and reuse;
never label an unexecuted check Passed. Do not duplicate old ledgers or detailed logs.
CI and mandatory release gates remain unchanged. Avoid builds, dependency downloads
and environment setup unless the changed boundary actually requires them.

Record **every executed verification invocation**, including failed diagnostics
and reruns, in the task's existing acceptance/checkpoint receipt linked from
[Progress](PROGRESS.md). Keep one compact row per invocation (a receipt may link
to its machine-readable per-command records). Include command/test identifier,
purpose and covered functionality, commit/artifact hash, result, new/rerun status
and the specific reason for a rerun. Record reused evidence separately with its
source and why it remains valid; do not imply it was executed again.

Detailed output belongs under ignored `.buildlog/`, normally `.buildlog/verify/`;
never paste repetitive terminal progress into Markdown. `verify.ps1` already
records command, source, exit code and log paths; the task receipt supplies purpose,
coverage and reuse/invalidation decisions. Platform/manual checks need the same
identity/result record. For example:

| Invocation / purpose | Source / artifact | Result | New or rerun / reason |
| --- | --- | --- | --- |
| `verify.ps1 -Mode Feature -Feature android-updates`; updater regressions | commit and linked helper receipt | pass/fail and log | rerun: changed Range validation |
| 16 KiB cold boot, render/write/reopen; runtime compatibility | APK SHA-256, emulator/image/page size | observed result and log | rerun: prior guest system failure; controlled environment change |

Before a code, dependency, assertion, artifact or environment change, identify
which recorded results it invalidates. Rerun those checks and preserve unaffected
passes. Minimize simultaneous emulators/builds, repeated large downloads and
unrelated platform rebuilds; never reduce meaningful coverage or bypass signing,
schema, backup, data-preservation or release-integrity gates to save resources.

## Checks by functionality

For an isolated 16 KiB artifact-only runtime gate, manually dispatch
`.github/workflows/android-16k-runtime.yml` with the existing x64 release asset ID
and validated SHA-256. It uses a fresh Linux/KVM official API-36 16 KiB guest,
checks system stability before installation, then renders, creates/reopens and
completes a synthetic task. It does not build the app or rerun host suites.
Its evidence artifact records the exact APK hash and observed runtime behavior;
it does not prove physical ARM64/OEM behavior or the installation approval UI.
GitHub requires the workflow to be registered on the default branch for ordinary
manual dispatch. While introducing it on `feature/android-mobile`, its narrowly
scoped workflow-file push bootstrap uses the explicit `[16k-runtime]` commit
marker. Draft-asset retrieval requires push visibility; the job has no signing
keys and makes no repository/release write calls. Keep candidate-source CI
evidence distinct from these test-harness commits.

| Change | Focused checks and constraints |
| --- | --- |
| Markdown only | Validate changed links/paths and commands; review diff; `git diff --check`. No Flutter tests or builds. |
| Flutter UI | Relevant `test/*_test.dart`, targeted analysis, isolated rendered inspection; narrow size/larger text and theme variants when affected. Apply [Ultimate UI/UX](../.agents/skills/ultimate-ui-ux/SKILL.md) through the [UI quality workflow](CODEX_WORKFLOW.md#ui-quality-workflow). |
| SQLite/domain | Relevant repository/domain tests plus migration, round-trip and stale-write cases for changed data. Start with `test/repository_test.dart`, `test/database_initialization_test.dart`, `test/migration_gate_test.dart` when changing schema/startup. Never use a personal database. |
| Settings/profile | Feature tests plus `test/profile_isolation_test.dart`, `test/settings_transfer_test.dart` or `test/appearance_preference_store_test.dart` when those boundaries change. Check malformed/newer formats and local vs portable fields. |
| Calendar/scheduling | `test/calendar_test.dart`, `test/calendar_improvements_test.dart`, `test/event_recurrence_test.dart`, `test/scheduling_engine_test.dart`, `test/scheduling_repository_test.dart` as affected. Native Calendar is a separate rendering path. |
| Widgets/IPC | `test/widget_configuration_test.dart`, `test/widget_edit_session_test.dart`, `test/widget_settings_page_test.dart`, `test/native_widget_service_test.dart` as affected; native Release/self-test for native changes. Follow [widget manual checks](windows-widget.md) for painting, input, shell, DPI and menus. |
| Backup/Drive | `test/backup_service_test.dart`, `test/import_export_test.dart`, `test/cloud/cloud_backup_test.dart`, `test/cloud/google_drive_test.dart` as affected. Include tampering, interrupted restore and settings portability. Real OAuth/recovery needs authorized isolated acceptance: [Drive guide](GOOGLE_DRIVE_BACKUP.md). |
| Updater/packaging | `test/software_update_service_test.dart`, `test/update_helper_launcher_test.dart`, `test/software_updates_page_test.dart`; relevant PowerShell harnesses below and [update recovery](SOFTWARE_UPDATES.md). |
| Integration/release | Full analysis and serial suite, relevant native/Windows builds, packaged self-test and all [release gates](RELEASE.md). Exact-source CI success is required for release; candidate CI is not publication approval. |

Select relevant files, not every file in a row. Widen after shared behavior changes,
an unexplained failure or at integration/release checkpoints. Re-run after new
changes invalidate prior evidence; do not blindly repeat passing gates.

## Commands

Actual startup recovery and managed attachment opening use profile files. On
Windows, run `./tools/dev/test-profile-journeys.ps1` to execute their acceptance
fixtures with disposable child `APPDATA` and `LOCALAPPDATA`. The runner prints
the resolved profile and retains exact commands, source hashes and results under
ignored `.buildlog/verify/profile-journeys/`. It does not delete those receipts or
the successful legacy upgrade and Before upgrade snapshot. The real-profile
cases explicitly skip in ordinary host runs without this isolated environment;
an ordinary full-suite pass therefore does not establish startup acceptance.
Never substitute personal profile paths. Run this separately from other Flutter
test processes to avoid native-asset contention.

Use [the shared crash-worker harness](../test/support/sync_crash_barrier.dart)
for sync tests that start and forcibly terminate a Dart worker. It serializes
workers that share JIT native assets, since Windows holds the SQLite DLL open
until the worker exits.

The optional helper preserves these commands and CI as the authority:

```powershell
# Preview only; explicit test groups are in tools/dev/features.json.
./tools/dev/verify.ps1 -Mode Feature -Feature drive -Plan
./tools/dev/verify.ps1 -Mode Quick -ChangedPaths lib/data/profile_fingerprint.dart -Tests test/cloud/cloud_transfer_history_test.dart
./tools/dev/verify.ps1 -Mode Feature -Feature android-updates
./tools/dev/verify.ps1 -Mode Full
# Full host checks plus Windows Release and isolated packaged companion self-test:
./tools/dev/verify.ps1 -Mode Full -Platform Windows
# Requires a disposable AVD: existing harness installs test builds into that app.
./tools/dev/verify.ps1 -Mode Feature -Feature android-updates -Platform Android -Device emulator-5580 -AndroidSdk '<SDK>' -JavaHome '<JDK 21>' -GradleUserHome '<existing cache>'
python tools/dev/check-docs.py
python -m unittest discover -s tools -p test_dev_verify.py
```

Quick checks formatting/analysis of explicit paths plus explicitly selected tests.
Feature uses a reviewed group and any extra `-ChangedPaths`/`-Tests`. Full checks
all source formatting/analysis, the complete serial host suite and release/helper
Python tests. `-Platform Android`, `Windows` or `All` adds the existing platform
harnesses/builds; `None` is the host-only default. Full with platform None does
not satisfy device/build release gates. Android's harness covers native negative
APK verification and mobile restore, not interactive system-installer approval.
Run that approval/cancellation sequence from [Android release](ANDROID_RELEASE.md)
separately. Logs, exit codes, revision/dirty flag and timings are retained under
`.buildlog/verify/`; failures stop later steps and return nonzero. Test groups are
starting points; add related tests when dependencies cross the listed boundary.

The helper never resolves packages, cleans caches or guesses affected tests.
Run `flutter pub get` when lockfile/dependencies change. CI's independent full
commands remain mandatory before publication. Host tests cannot establish real
Google authorization, OEM delivery or physical native input behavior.

The debug Android harness uses the committed pubspec version code as its baseline
and baseline + 1 for its unpublished candidate; fixture version names come from
the APK metadata. It refuses an installed version above that baseline.
Archive the disposable emulator profile first, then explicitly add
`-AllowDebugDowngrade` to reuse it, or select a fresh AVD. This installs the
same-source debug baseline with `adb install -r -d`; it never uninstalls data to
recover from an error. Its Flutter Drive runner retains the test installation.
This requires the explicit `--keep-app-running` flag: default Drive teardown also
uninstalls its app. Archive before deployment even when that flag is supplied.
Negative fixtures are never installed. CI's ephemeral Android runner is separate.
Release builds must regenerate mode-specific plugin tooling: omit `-NoPub` on
`tools/build-android.ps1 -Mode Release`. Flutter's `--no-pub` also skips plugin
regeneration and can leave a debug-only integration-test registrant in place.
Keep Flutter commands that regenerate platform files sequential within a checkout.

Android additions: `test/mobile_workspace_test.dart` checks compact/tablet,
text scaling, RTL/dark layout, task CRUD and unsaved Back protection;
`test/android_platform_test.dart` covers navigation preferences and reminder
planning; `test/cross_platform_backup_test.dart` moves a verified snapshot
between two isolated profiles in both directions. These host tests do not prove
native Android behavior. Run `flutter test integration_test/android_workflow_test.dart
--flavor github -d <isolated-emulator-id>` for the on-device SQLite/UI workflow, then the manual
matrix in [Android](ANDROID.md). Never reset a personal app profile to run tests.

Android widget rendering/capabilities also have an opt-in native harness:

```powershell
./tools/test-android-widgets.ps1 -Device emulator-5580 -ApplicationApk build/app/outputs/flutter-apk/app-github-debug.apk -AndroidSdk '<SDK>' -JavaHome '<JDK 21>' -GradleUserHome '<existing cache>'
```

Use an archived disposable emulator with app lock disabled and the same-source,
debug-signed APK. Retain the CMake/Ninja process PATH described in Android setup
when using local toolchain overrides. The harness never opens SQLite: it restores
its temporary projection and removes only its own test keys in `finally`.
It captures real RemoteViews in a native test window at three sizes, both themes,
zero/one/twelve items and normal/200% text, and verifies footer geometry and
one-use capability identity. PNGs remain in app-private cache under
`widget-render-acceptance`; copy them to ignored build logs for review.
These renders do not establish launcher drag/OEM resizing or physical TalkBack.

```powershell
# Substitute the actual changed Dart files; formatting check does not rewrite.
dart format --output=none --set-exit-if-changed lib/features/settings/widget_settings_page.dart
flutter analyze --no-pub lib/features/settings/widget_settings_page.dart
flutter test --no-pub test/widget_settings_page_test.dart
# Whole-project integration/release checks:
flutter analyze --no-pub
flutter test --no-pub --concurrency=1
dotnet build experiments/widget-shell-probe/widget-shell-probe.csproj -c Release
./tools/build-windows-release.ps1
```

Unit and Flutter widget tests both use `flutter test`. Android's separate
`integration_test/android_workflow_test.dart` exercises real app-private SQLite,
mobile editors and staged restore on an isolated emulator. `lib/driver_main.dart` is a debug-only live-inspection
entry point, not a release target. The opt-in real companion test is
`test/native_widget_launch_integration_test.dart`: it requires
`TODORBIT_NATIVE_SERVICE_EXE` pointing to an absolute companion path and fresh
`APPDATA`/`LOCALAPPDATA` beneath
`.buildlog/widget-customization/native-service-profile/`. Read its guard before
running; without the executable variable it skips deliberately.

For native checks, launch the built executable with `--self-test` **after**
configuring an isolated child-process environment as in Development. Source
build output is `experiments/widget-shell-probe/bin/Release/net10.0-windows/`;
distribution checks use `build/windows/x64/runner/Release/TodorbitWidget.exe`.
Actual-HWND `--lifecycle-self-test` supplements the self-test on an interactive
Windows desktop; neither establishes physical input/DPI acceptance.

Existing isolated harnesses (read parameters before running; require matching
Release binaries/packages):

```powershell
./tools/test-google-drive-release-config.ps1
./tools/test-single-instance.ps1
./tools/test-update-handoff.ps1
./tools/test-portable-update.ps1 -Package release/Todorbit-X.Y.Z-win-x64-portable.zip
./tools/test-portable-update.ps1 -Package release/Todorbit-X.Y.Z-win-x64-portable.zip -ExpectFailure
```

Replace `X.Y.Z` with the candidate version. Installer execution belongs in a
disposable Windows user/VM, not the owner's normal account. Redirecting APPDATA
alone does not isolate Windows Credential Manager or installer registration.

## Continuous integration and GitHub Actions

GitHub Actions workflows are partitioned into lightweight automatic gates and on-demand comprehensive verification to prevent wasteful cloud consumption and runner thrashing:

1. **[Lightweight CI](../.github/workflows/ci.yml)**: all pull-request base branches
   (not source-branch prefixes), and pushes to `main`; stable check name
   `Fast Cross-Platform Checks`. Ubuntu, serial portable safety smoke tests,
   analysis of lib/selected tests, route/docs validation and focused Python helper/
   workflow shell-contract tests. Full repository analysis remains a comprehensive
   gate. The 25-minute ceiling includes a cold SDK/dependency setup; first cloud
   timings must confirm/tune this budget. Mobile/theme breadth moves to manual
   regression; migration/CAS/recurrence/codec/backup coverage stays automatic,
   with sync-journal and CAL-01 integrity tests included.
2. **[Comprehensive Verification](../.github/workflows/manual-verification.yml)**:
   workflow_dispatch only. `flutter-regression` = full test/ directory on Ubuntu;
   `calendar-recurrence` = calendar, recurrence, integrity and history;
   `persistence-sync` = database, CAS, sync/backup and series-integrity;
   `all-host` = full analysis, default docs, all Python tools and test/ on Ubuntu.
   No native/device acceptance is implied. Host commands fail through `tee`,
   capture bounded logs and stop after failure. `Selected verification result`
   reports the selected branch, including failure/cancellation/skips.
3. **[Windows CI](../.github/workflows/windows-ci.yml)**: direct dispatch or reusable
   call, Windows-2022, full host/analysis plus unchanged OAuth/package, C++/.NET,
   native writer/background/self-test, portable/installer/checksum gates. Release
   candidate artifact remains unpublished. First Python suite failure cannot be
   hidden by a later successful suite. No ordinary push/PR trigger remains.
4. **[Android CI](../.github/workflows/android-ci.yml)**: existing filtered push/PR,
   direct dispatch and reusable call remain. Android-focused host tests/debug APK
   execute on Windows; API-35 KVM AVD update/Drive-contract integration executes on
   Ubuntu. This is emulator evidence, not physical-device acceptance. Its update
   fixture does not run `android_workflow_test.dart`; `DEF-AND-WORKFLOW` remains
   distinct. Existing automatic Android builds/emulator can still run alongside
   Lightweight CI for matching paths; INFRA-01 does not make every PR cheap.
5. **[Android Release](../.github/workflows/android-release.yml)**: protected
   `android-signing` environment and both reusable validation dependencies remain
   unchanged; neither manual verification nor PR CI receives signing secrets.
6. **[Android 16 KiB Runtime](../.github/workflows/android-16k-runtime.yml)**: separate
   artifact-only API-36 ps16k gate. Needs candidate APK identity/hash, with optional
   previous APK for upgrades; not invoked by the generic Android group. Its
   existing trusted contents-write draft-asset access is not inherited by tests.
7. **[Pages CI](../.github/workflows/pages.yml)**: independent validation and explicit
   owner-approved main-branch deployment remain unchanged.

Direct actions in the three INFRA-01 workflows use verified commit SHAs. Nested
legacy Android/release/Pages workflows retain existing action-tag references;
no new secret inheritance, write token, self-hosted runner or signing path was
introduced. Treat future dependency updates as reviews; SHA pins do not lock all
transitive action internals. Checkout credentials are not persisted. Dependencies
are resolved with `--enforce-lockfile`; PR cache scope must remain isolated from
trusted branch caches. Diagnostic uploads include named log files only, not
whole .buildlog profiles/databases/packages.

### First GitHub execution and required-check migration

No cloud run or repository branch-protection/ruleset inspection has occurred.
Only after an authorized reviewed commit/push, open a PR to obtain the new
`Fast Cross-Platform Checks` status. An owner must inspect Settings > Rules /
Branches: any formerly required standalone `windows` context from **Windows
checks** no longer runs automatically. After observing the intended new check,
replace that stale requirement with `Fast Cross-Platform Checks` if lightweight
PR policy is desired; retain Windows/Android exact-candidate release gates.
Existing Android/Pages check names are unchanged. Do not assume nested
`Windows Full Verification / windows` or `windows-regression / windows` satisfies
an old standalone required check. If merge queue is enabled, add and validate a
`merge_group` trigger before requiring this workflow for queue entries.

Dispatch workflows must exist on the default branch before the dispatch API/UI
can invoke them. After that registration, select the exact candidate ref:

```powershell
gh workflow run manual-verification.yml --ref <reviewed-branch> -f test_group=calendar-recurrence
gh workflow run manual-verification.yml --ref <reviewed-branch> -f test_group=windows-verification
gh workflow run manual-verification.yml --ref <reviewed-branch> -f test_group=android-verification
```

Run the other three host groups as needed. Observe actual run/check conclusions,
checked-out SHA, selected-group summary, cache/cold timing and retained diagnostics;
review a controlled failing run to confirm remote failure propagation. Keep
`DEF-CI-CLOUD` pending until these checks are evidenced. Linux Flutter SDK download
availability (project pin 3.47.7) and cloud runner compatibility are acceptance,
not established by local YAML/actionlint or Windows test passes.

Record passed, failed, skipped and unverified checks separately in the
[Test run ledger](TEST_RUN_LEDGER.md) and [Deferred verification](DEFERRED_VERIFICATION.md).
No green host check substitutes for appropriate release/platform acceptance.
