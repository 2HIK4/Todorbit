# UIUX-03 independent beta review — 2026-11-15

Scope: Navigation, Custom Views, Resources, Task Details and Focus Workspace on
Windows/Android. Ship review with repairs of confirmed blockers; no general
redesign, push, merge or publication. All work uses synthetic data.

## Source and decision

Base: `e7810d2cf9b2ee19dd7506dc1807550fa919f2fd`, branch
`codex/independent-beta-review`. Initial state: 20 modified tracked files and six
untracked files (three Gemini implementation files and three unrelated storage/
architecture documents). Latest documented checkpoint is DRV-01 / beta 21,
following the independently recorded UIUX-02/beta-20 checkpoint. UIUX-03 was not
committed or source-bound to a test receipt.

[Source identities](UIUX03_REVIEW_SOURCE_MANIFEST_2026_11_15.json) retain initial
dirty-file hashes and final reviewed source/assertion/dependency identities.
Raw diagnostics are ignored under `.buildlog/uiux03-review/`.

**Publication is NOT APPROVED yet.** Scoped automated checks support the repaired
code, subject to the outstanding native/runtime/candidate acceptance below.
Code review and publication acceptance are separate decisions.

| Review area | Current result and boundary |
| --- | --- |
| A — Database/data preservation | PASS for host migration, gate/reopen, sync capture/apply, snapshot/scheduled restore, managed bytes, local-reference exclusion, saved filters/icons and portable visibility. Real Windows/Android service exchange remains manual acceptance. |
| B — Chrome drag/drop | NEEDS MANUAL TESTING. The missing native URL format is repaired; Flutter channel URL/file/folder/image tests pass. Actual Chrome dragging into an installed app has not been observed. |
| C — Focus | PASS for focused host state/accounting/recovery checks; device background/suspend/input acceptance remains unperformed. |
| D — Experience/integration | NEEDS MANUAL TESTING. Mobile Details/edit/return and mini-timer return, narrow Focus, desktop search, pinned/More navigation and persistent completion pass on the host. Native/device layout/input acceptance remains open. |

## Confirmed defects and repairs

1. **Migration and portable relationships:** Gemini added a table while retaining
   schema 28 and creating it in `beforeOpen`, bypassing the existing upgrade
   backup gate. Use explicit transactional schema **29** migration, including
   existing 28 profiles and idempotent reopen. Preserve preexisting assignment
   rows, resources and alarm tables. Snapshot validation now requires the table
   for schema 29. Register it for sync capture/apply, with local file/folder/app
   references excluded and cascade tombstones retained. Shared sync code discovers
   keys/foreign keys from SQLite. No cloud protocol/key/ownership redesign.
   Native companion's supported maximum changes from 28 to 29; it still never
   migrates the database. Older batches (26/27/28) remain readable by the new
   client; older clients reject schema-29 batches with the existing update-required
   error. Update **all paired clients** before exchanging new batches.
2. **Visibility was device-local:** category/project exclusions were only in
   profile JSON. Persist/validate them through existing SQL portable preferences,
   project back into JSON and invalidate cached tasks after remote application.
   Saved Views already use `saved_views.filter_json`; round-trip tests verify
   multi-select fields and icons without adding a second store.
3. **Actual Chrome links were unsupported:** the runner accepted `CF_HDROP` only;
   `.url` parsing did not fix webpage drags. Accept/read bounded UTF-16
   `UniformResourceLocatorW` data and forward a separate URL payload for normal
   repository validation. Keep file handling, shortcut parsing and URL
   normalization. Dropped folders stay external links even with the attach
   choice; managed image bytes are portable. Restore the underlying Resources
   drop receiver when a nested editor closes; batch draft URL additions.
4. **Focus accounting/lifecycle:** independent decrement counters did not stop
   recorded work at countdown completion; reset/mode/phase transitions could
   disagree with the ledger and another task's timer could be controlled.
   A small pure `FocusSession`, owned by `AppController`, now retains fractional
   monotonic elapsed time and interval state across navigation. Explicit
   repository boundaries cap completed work at its deadline, pause/reset/mode
   switches pause work, and breaks never enter work entries. Ready work phases
   wait for Start. Existing ownership restrictions stay in force; no automatic
   stopping of another task. Mini-timer controls use the same bounded state.
   Any running local timer found at controller startup now requires explicit
   recovery even after a short restart, rather than counting powered-off time
   until the old 120-second threshold. Focus reuses the existing recovery/
   ownership UI; Details caps unconfirmed open time at the checkpoint. True
   zero-duration rows stay hidden; positive subsecond rows display `<1s` and
   contribute to the same unfiltered union totals and stopwatch calculation.
5. **Details navigation/editing:** mobile editing used to pop Details and reuse
   its stale task object. Keep the Details route, read the latest task before
   editing and return to it after Save/Back. Resource-created subtasks now return
   their actual record to assignment UI and retain the parent selection, avoiding
   a silent jump to the child.
6. **Bulk deletion safety:** Empty Trash read a fresh selection after confirmation
   and multi-item loops could commit a prefix before a later blocker. Snapshot
   the confirmed records, transact the complete batch and refresh after commit.
   Archived deletion checks the reviewed archived state/revision, rejecting a
   concurrently restored record. Existing timer, relationship, purge and tombstone
   safeguards remain authoritative. No automatic expiry purge was added.
7. **Narrow Focus rendering:** the total-time banner overflowed by 64 pixels on
   the 360px mobile journey. Allow it to wrap; timer mode/phase groups also wrap.
   No product-wide visual refresh or token changes were made.
8. **Test assertion correction:** resource assignments are a set; a Gemini test
   assumed order for rows with identical creation timestamps. Compare unordered
   membership without changing persistence semantics to satisfy that assumption.

The separate alarm implementation is unchanged: no diff in alarm rules/planner,
AlarmField, alarm settings, Windows `Alarms.cs` or Android `AlarmDelivery.kt`.
No alarm branch/current working copy was found in the worktree inventory.
Shared controller/editor/schema files were reviewed for overlap. The companion
change is limited to its schema upper bound, not reminder delivery.

## Evidence policy and verification

Gemini's queue lists passing analysis, 24 migration/gate checks, repository and
UI suites. It supplies no dirty-source/dependency fingerprints, timestamped
commands or raw logs for this implementation. These claims were **not treated
as current independent proof**. Existing broad release evidence stays historical;
the complete suite, unrelated repository audits, alarm implementation and release
infrastructure were not rerun or rewritten. Passing focused results below are
reused across later non-intersecting edits; no all-suite pass is claimed.

All commands run from the repository root on Windows, serial Flutter tests with
`--no-pub --concurrency=1`, using in-memory or disposable SQLite/profile data.
Execution window is 2026-11-15, UTC+03:00. Dependencies are unchanged. Normal
Drift multiple-database warnings in fixtures use distinct executors/files; they
are retained in the logs and are not production-profile writes.

| Receipt log | Command/scope | Result and reason |
| --- | --- | --- |
| `pre-data.log` | `flutter test --no-pub --concurrency=1 test/uiux03_review_test.dart` | Fixture compile failure: missing TaskDraft import; corrected before using evidence. |
| `pre-drop.log` | Same flags, `test/uiux03_resources_widget_test.dart` | Existing file journey passed; new Chrome URL payload failed against Gemini UI. |
| `pre-focus.log` | Same flags, `test/uiux03_focus_widget_test.dart` | Fixture cleanup disposed controller twice, obscuring assertions; not counted as proof. |
| `analyze.log` | `flutter analyze --no-pub` with 17 explicit affected paths | Five brace-style diagnostics, corrected. |
| `focused.log` | Same test flags, review/sync/focus-widget/resources-widget/focus-session files | 9 pass / 1 fail: sync fixture applied only its first independent group. |
| `sync-rerun.log` | Same flags, `test/uiux03_sync_test.dart` | 1 pass after draining incoming groups; no production workaround. |
| `defect-probes.log` | Review/focus-widget tests with original defective boundaries temporarily restored | Probe compilation failed on multiline preference formatting; exact saved bytes restored in finally. Not counted. |
| `defect-probes-valid.log` | Same files, `--name 'schema 28 upgrade\|resource assignments participate\|category and project visibility\|selecting bounded mode\|interrupted Focus'` | Five expected failures with original defective boundaries restored; guarded restoration returned reviewed bytes. These are fault probes, not an untouched Gemini-tree suite. |
| `critical-final.log` | Same flags, `test/uiux03_review_test.dart test/uiux03_sync_test.dart test/uiux03_focus_widget_test.dart test/uiux03_resources_widget_test.dart test/focus_session_test.dart test/database_initialization_test.dart test/migration_gate_test.dart test/task_resources_test.dart test/time_tracking_repository_test.dart test/saved_views_test.dart test/trash_repository_test.dart test/cloud/sync_batch_codec_test.dart test/cross_platform_backup_test.dart` | 71 pass / 1 failed order assumption. Includes migration kill/rollback fixtures, gate, resources, restore, ownership/recovery, filters and sync/codec boundaries. Passing non-intersecting checks reused. |
| `assignment-assertion.log` | Same flags, `test/task_resources_test.dart --plain-name 'subtask resource assignments'` | 1 pass with set-membership assertion. No broad rerun. |
| `ui-final.log`, `navigation-diagnostic.log` | New resource/mobile journeys, then navigation-only `--timeout=45s` | Image fixture asserted before real file I/O finished; mobile fixture awaited directory I/O inside FakeAsync and was interrupted. Corrected fixture isolation/pumping. |
| `additional-final.log` | Same flags, `--timeout=60s test/uiux03_navigation_test.dart test/uiux03_transfer_test.dart` | 3 transfer/codec passes, reused; navigation fixture looked for a Cancel button absent in compact editor. |
| `journeys-final.log`, `image-drop-diagnostic.log` | New mobile/resource journeys, then image-only `--plain-name 'Image file drop'` | Confirmed mobile total-banner overflow and premature image assertion. Fixed banner; bounded I/O/frame drain proves resulting attachment. |
| `journeys-fixed.log` | Same flags, `test/uiux03_navigation_test.dart test/uiux03_resources_widget_test.dart` | **5 pass**: mobile Details Save/reopen/Back, mini-timer return, Pomodoro width; actual file/folder/image/URL channel operations and persisted results. |
| `navigation-regression.log` | Same flags, `test/workspace_test.dart test/mobile_workspace_test.dart --name 'Quick Search\|view information opens\|unpinned mobile view\|mobile task completion'` | **4 pass**, affected desktop search and both navigation shells. |
| `focus-critical-final.log` | Same flags, `test/uiux03_review_test.dart --name 'countdown completion\|short restart\|bounded work'` | **3 pass**, including added countdown deadline assertion and final pause ordering. |
| `analysis-final.log`, `analysis-clean.log` | `flutter analyze --no-pub` over modified and new `lib/` and `test/` Dart paths (36) | Five unused copied test imports removed; final **0 issues**. |
| `format*.log` | `dart format` on explicit edited source/assertion paths | Completed. `git diff --check` passes; this does not imply a clean working tree. |

Final evidence spans **84 distinct named Flutter checks**, including the native
writer test, with the failed assignment assertion repaired and individually
rerun. This is an aggregate of relevant passing receipts, not a fresh 84-test
all-suite invocation. Last source edits intersecting timer pause/recovery were
covered by `focus-critical-final.log`; unaffected earlier passes were reused.

| Additional receipt | Execution and result |
| --- | --- |
| `windows-release.log` | `./tools/build-windows-release.ps1`: PASS, 208.8s. Existing approved Drive configuration/bundle assertion and three signed CRT DLL checks retained. This compiles the Windows URL-drop change and Release companion; no installer, APK or publication. |
| `native-self-test.log` | `./tools/dev/native-self-test.ps1 -Executable build/windows/x64/runner/Release/TodorbitWidget.exe`: PASS, explicit disposable APPDATA/LOCALAPPDATA; native persistence/revision/alarm self-tests. Physical sound/DPI/input not inferred. |
| `native-writer.log` | `TODORBIT_NATIVE_SYNC_EXECUTABLE=<absolute Release companion>; flutter test --no-pub --concurrency=1 test_driver/native_sync_writer_test.dart`: 1 PASS, opening schema 29 and preserving transactional journal/JSON projection behavior. |
| `runtime-transcript.txt` | `flutter run --debug --no-pub -d windows -t test_driver/driver_main.dart`, with explicit child APPDATA/LOCALAPPDATA/TODOPILOT_ISOLATED_PROFILE: PASS launch, 167.1s build; CLI `r` reload completed in 655ms; `q` closed only the isolated instance. Verified resolved database below the review root and `user_version=29` before driver interaction. |
| `live-probe.log` | Disposable Flutter Driver probe initially used an unavailable `setFrameSync` client method: fixture compile failure; removed it. |
| `live-probe-fixed.log` | Driver health OK and synthetic UI task creation succeeded; immediate row-open wait timed out during the create/close sequence. Retained as a failed probe, not a complete runtime pass. |
| `live-existing.log`, `runtime-focus.png` | Existing synthetic row opened Details, then Focus, then Countdown; health OK, screenshot captured and visually inspected. This establishes the recorded Windows Debug journey only. The earlier driver wait timeout remains in the transcript; no clean-all-runtime-errors claim. Dart MCP discovery could not find this CLI launch, so CLI reload and the existing Driver extension were used. |

Release artifact SHA-256 values:

- `Todorbit.exe`: `30e421ecaaf56e0eaa56fd88a2361615caa966ba1312fe3e043deb4d5f981ae5`
- `TodorbitWidget.exe`: `d97e5460c25f679d45849f4d421252d1865929e928e32ceb19453f6005a59d96`
- `data/app.so`: `566a5704e18dbc3ad99fc88f5e994172b510cd9581fdf38af9b92a33dd60441d`

## Git accounting and handoff

HEAD remains `e7810d2cf9b2ee19dd7506dc1807550fa919f2fd`; no commit was requested
or made. All reviewed Gemini implementation, confirmed repairs, assertions and
review records are explicitly staged as the local checkpoint. The three initial
unrelated documents remain untracked and byte-identical to the initial manifest.
`git diff --cached --check` and `git diff --check` are whitespace checks only;
the working tree is deliberately **not clean**. Review status belongs in history;
publication/acceptance gaps remain in Deferred Verification. No push/merge/tag or
release operation was performed.

## Remaining acceptance and material limitations

- Actual Chrome address-bar/hyperlink drag, local file/image/folder/shortcut drops,
  DPI coordinates, editor-overlay receiver restoration, cancel and invalid URL
  feedback on Windows must be observed in a disposable candidate profile.
  The supported URL format follows [Microsoft Shell clipboard formats](https://learn.microsoft.com/en-us/windows/win32/shell/clipboard)
  and [Chromium Windows drag provider](https://chromium.googlesource.com/chromium/src/+/refs/heads/main/ui/base/dragdrop/os_exchange_data_provider_win.cc).
- Actual Android Back/IME/fonts/touch/rotation/background/process death and
  accessibility, Windows keyboard/mouse/mixed DPI, and real two-client Drive
  exchange remain unperformed. Host shell tests do not prove installed Android.
- Focus mode/config/remaining state survives navigation within the process;
  after process restart the durable work timer uses explicit checkpoint recovery.
  It does not silently reconstruct a Pomodoro phase or count powered-off time.
  User-selected **Keep elapsed time** intentionally authorizes including that gap.
- All paired clients need schema-29 support for new batches. Snapshot backups and
  incremental Sync remain separate. No downgrade migration or old-client write
  compatibility is claimed; existing Before Upgrade/Before Restore safeguards stay.
- No candidate APK/installer/update/16-KiB runtime or real OAuth acceptance was
  performed for this source. Beta-20/21 packages prove only their historical source.
  Stable, version numbers, CI, installer identity, updater and published tags/assets
  are unchanged. Packaging/publication needs separate authorization and release gates.

Final Git check: **45 review paths staged**, no unstaged tracked changes; only the
three preserved unrelated documents are untracked. Reviewed index blobs match the
manifest. Both staged and unstaged whitespace checks pass. Toolchain: Flutter 3.47.7, Dart 3.13.5.
