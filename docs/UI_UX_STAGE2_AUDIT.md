# Stage 2 UI/UX audit and repairs — 2026-11-02

Focused follow-up: [Stage 2.1](#stage-21-follow-up--2026-11-03). The original
Stage 2 findings/evidence below remain historical to their recorded source.

Baseline `f7954d4`, initially clean; branch `fix/stage2-ui-quality`. Audit, fix
and proportionate polish across the actual Windows/Android presentation. No
version, schema, backup, cloud policy, package identity or release changes.
Only synthetic data in in-memory databases and isolated profiles is authorized
for checks. No remote push/merge/publication.

The updated repository-local [Ultimate UI/UX skill](../.agents/skills/ultimate-ui-ux/SKILL.md)
was present in this fresh session's skill catalog and read from its actual path.
Applied audit workflow, all 28 issue-catalog categories/303 symptom-repair entries,
fix patterns, Flutter engineering/verification, matrix and report references.
Project guidance: AGENTS, Codex workflow, Testing, UI Skill Integration,
Architecture/feature map, Design, Theming, Android/setup, Development and native
widget guide. Windows conventions and existing Todorbit tokens remain authoritative.

## Coverage semantics and constraints

`INSPECTED_PASS` describes only the named executed check. `FIXED_VERIFIED`
requires a correction and recheck. `INSPECTED_FAIL` is a reproduced open defect.
`NOT_TESTED` means an applicable unexecuted case; `BLOCKED` names an unavailable
capability. Source inspection, host widget/offscreen tests, real runtime and
physical OS/device acceptance are distinct. Native and externally hosted
surfaces are not established by Flutter tests.

Previous receipts inspected: [UI hierarchy audit](UI_HIERARCHY_AUDIT.md),
[Android refinement](ANDROID_UI_REDESIGN.md), recent Progress checkpoints and
`.buildlog/verify/` receipts. Their published-source/artifact evidence is
historical; no changed behavior is accepted merely because beta 5 passed.
Unchanged native/package behavior does not require repackaging for these repairs.
Current task evidence is under ignored `.buildlog/verify/stage2-ui/`.

## Reachable surface inventory

The inventory reconciles the desktop/mobile navigation, settings enum and drawer,
feature classes, nested dialog calls and native adapters. Rows group related
states, not claims that every variant was visited. W = Windows, A = Android.
Only the named runtime samples have executed statuses; remaining variants are
NOT_TESTED. Located/reviewed source is not a visual pass.

| ID | Entry/surfaces and owner | Platform | Risk / relevant variants | Runtime status |
| --- | --- | --- | --- | --- |
| S01 | Main shell, Today/dashboard, All, Inbox, Anytime, Upcoming, Overdue, Waiting, Completed; `workspace/workspace.dart`, `mobile/mobile_workspace.dart` | W/A | P1; empty/populated, search/sort, selection, responsive rail/bottom navigation/drawer | INSPECTED_PASS samples R01/R06; final selection R19 |
| S02 | Task create/details/editor, status/priority, estimates/protection, planned day/deadline; `workspace/task_editor.dart` | W/A | P1; save/error/retry, optional dates, unsaved close, IME/large text | INSPECTED_PASS Windows sample R01; Android runtime NOT_TESTED |
| S03 | Task checklist/subtasks/dependencies; composition section, checklist dialog, text expansion | W/A | P1; create/edit/reorder/remove, long text, checkbox targets | NOT_TESTED |
| S04 | Resources: links, files/folders, attachment import/drop, Windows-path relink; resources section/native file dialogs | W/A | P1; unavailable paths, permission/cancel/failure, platform document picker | NOT_TESTED |
| S05 | Recurrence/series/skip/resume/end, progressive plan and task sequences; matching workspace dialogs | W/A | P1; occurrence/future/series scopes, validation, draft preservation | NOT_TESTED |
| S06 | Event create/edit/details, custom detail types, category/icon/color, meeting-link validation, reminder/repeat, duplicate/cancel/end/trash; `calendar/event_editor.dart` | W/A | P1; explicit/generated end, all-day/midnight, nested pickers/actions | FIXED_VERIFIED R07; IME sample R08; other variants NOT_TESTED |
| S07 | Planned work-session create/edit/delete/outcome; `calendar/session_editor.dart` | W/A | P1; task choice, duration, unsaved close | NOT_TESTED |
| S08 | Desktop calendar day/week/month, conflicts, agenda/cells/tooltips/navigation; `calendar/calendar_view.dart` | W | P1; long titles, selected/today, content filters, recurring items | NOT_TESTED |
| S09 | Mobile calendar day/week/month, date picker, date semantics/counts/agenda/add actions; `mobile/mobile_calendar.dart` | A | P1; inherited/explicit colors, long/empty, text scale | FIXED_VERIFIED R06/R07 for week/agenda; other modes NOT_TESTED |
| S10 | Category/project lists, management sheets/menus, rename/delete, icons/category event color; both workspaces | W/A | P2; long names, empty groups, nested pickers | NOT_TESTED |
| S11 | Quick search, Advanced Search, saved view create/edit/filter/sort; search/workspace dialogs | W/A | P2; zero matches, keyboard selection, long results | INSPECTED_PASS Android empty search render; saved-view flow NOT_TESTED |
| S12 | Templates/routines: create/apply/delete dialogs; `templates/templates_dialog.dart` | W/A | P2; empty/populated, category, apply validation | NOT_TESTED |
| S13 | Smart Reschedule approval, availability, schedule history/detail/restore preview; `scheduling/smart_reschedule.dart` | W/A | P1; preview/apply/cancel/conflict, scroll/actions | NOT_TESTED |
| S14 | Habits list/editor/log/history/rest days/archive; `habits/` | W/A | P2; empty/populated, type-specific forms, large text | INSPECTED_PASS base empty/new/cancel R10; populated states NOT_TESTED |
| S15 | Goals list/editor/links/milestones/progress/history; `goals/` | W/A | P2; long names, linked records, validation | INSPECTED_PASS base empty/new/cancel R10; populated states NOT_TESTED |
| S16 | Actual work/timer start/pause/stop/recovery/take control; manual work create/correct/delete; `time_tracking/` and active timer banners | W/A | P1; elapsed vs planned, interrupted state, nested modal/IME | NOT_TESTED |
| S17 | Statistics/report period/custom date controls and values; `reports/reports_view.dart` | W/A | P2; empty/populated, narrow/large text, real values | INSPECTED_PASS Android zero-data render; other periods NOT_TESTED |
| S18 | Archive/Trash tabs, restore/permanent deletion confirmations; `workspace/trash_dialog.dart` | W/A | P1; irreversible action clarity, empty/populated | NOT_TESTED |
| S19 | Settings hub rail/compact section selector; mobile settings route/navigation editor | W/A | P2; selected states, scroll/back, draft/apply | INSPECTED_PASS parent samples R02/R09; nested variants NOT_TESTED |
| S20 | Theme mode/custom palettes/presets/import/export/reset and color picker; `settings/theme_dialog.dart`, shared color picker | W/A | P2; light/dark/custom, preview/apply/cancel, invalid HEX | INSPECTED_PASS theme mode R02/R09; custom-theme runtime NOT_TESTED |
| S21 | Task display/defaults, sidebar order, startup destination, calendar content/week start; task view/sidebar dialogs and mobile settings | W/A | P2; saved state/live changes, selectors | INSPECTED_PASS week-start R02; nested Windows form BLOCKED R05 |
| S22 | Hotkeys; `settings/hotkeys_dialog.dart` | W | P2; focus/text editing, conflict/disabled state | INSPECTED_PASS nested default Hotkeys R04; rebinding NOT_TESTED |
| S23 | Notification preferences, Android permission/settings links, per-task/event reminder controls | W/A | P1; denied/unavailable, battery guidance, selected offsets | INSPECTED_PASS parent R03; actual delivery/permissions NOT_TESTED |
| S24 | Lock screen, PIN setup/change, biometrics/Windows Hello, idle/secure capture; `settings/privacy_dialog.dart`, main lifecycle | W/A | P1; locked/failed/cancelled, privacy/draft preservation | NOT_TESTED |
| S25 | Data profile/about-path dialog, database import/export, startup migration approval/failure/retry; main/workspaces | W/A | P1; no reset fallback, readable long paths, recovery actions | NOT_TESTED |
| S26 | Local backup create/history/import/export/restore confirmation/restart; `backup_dialog.dart`, backups page/restore dialog | W/A | P1; pending/error/cancel, verified Before Restore | INSPECTED_PASS parent R03; native picker/restore runtime NOT_TESTED |
| S27 | Drive snapshots/account/connect/upload/download/delete/history and passphrase/progress dialogs; `backups_cloud_page.dart` | W/A | P1; offline/unconfigured/retry, long names, secure input | INSPECTED_PASS disabled/disconnected parent R03; real cloud NOT_TESTED |
| S28 | Existing encrypted sync status/settings/pair/recovery/reconcile/conflicts; sync pages/shared status button | W/A | P1; disconnected/paired/quarantined/error, IME, field decisions | INSPECTED_PASS disconnected R03; pairing/conflicts runtime NOT_TESTED |
| S29 | Settings transfer category selection/path/import/export confirmations; `settings_transfer_dialog.dart` | W/A | P1; device-local/portable distinction, cancel/failure | NOT_TESTED |
| S30 | Windows updates/channel/check/download/pause/retry/install/restart; `software_updates_page.dart` | W | P1; no network/download/install performed for audit | NOT_TESTED |
| S31 | Android updates/GitHub vs Play/install permission/download/retry; `android_software_updates_page.dart` | A | P1; no package-manager interaction implied by host tests | NOT_TESTED |
| S32 | Widget enable/configure Tasks/Calendar, presets, layout/colors/reorder, preview/apply/all/cancel/dirty/history; widget settings/editor | W | P1; independent persisted settings, shared controls | INSPECTED_PASS disabled controls R03; native preview NOT_TESTED |
| S33 | Native Windows Tasks widget/header/tabs/quick add/editor/tray/context menu/date popup/tooltip | W native | P1; shell/input/DPI/lifecycle/transparent surfaces | Self-test R21; physical acceptance BLOCKED R15 |
| S34 | Native Windows Calendar widget/month/agenda/divider/menu/navigation | W native | P1; configured colors, bounds, scaling, main app closed | Self-test R21; parity gap R22; physical acceptance BLOCKED R15 |
| S35 | Legacy `DesktopWidgetApp` compatibility entry routes into native service | W | P2; independent activation, unavailable companion | Self-test supplement R21; compatibility activation NOT_TESTED |
| S36 | Android Tasks/Calendar launcher widgets/configuration, empty/locked/populated/footer, notification navigation | A native | P1; RemoteViews projections, resize/theme/OS/OEM | Geometry/capability pass R16; suspected visual issue R23; launcher NOT_TESTED |
| S37 | Shared select/menu/tooltips/date/time/weekdays/icon picker/text prompt/action bar/unsaved guard | W/A | P1; keyboard/touch/Back, disabled/selected, anchor and viewport/IME | INSPECTED_PASS sampled menus/pickers R02/R07/R09; host contracts R11/R13/R20 |
| S38 | Shared status/error/helper/scroll-edge feedback, loading/success/empty states | W/A | P2; repeated validation, text scale, focus/scroll stability | INSPECTED_PASS validation sample R12; original shaking sequence NOT_TESTED |
| S39 | Contributors, branding, Support/Project support, donation/external link disclosure | W/A | P3; long text, platform distribution availability | NOT_TESTED |

No separate onboarding wizard/account-creation flow was found. First-run flows
are empty states, migration approval, optional privacy and Drive/sync setup.
The existing sync implementation was discovered in source; this task preserves
it without expanding cloud functionality. iOS/web/browser engines are outside
the supported task scope (N/A); no installed native OS behavior is inferred.

## Findings and remediation ledger

| ID | Priority | Established cause/scope | Correction | Status |
| --- | --- | --- | --- | --- |
| F01 / A | P2 | Event/session/task inner lists reserve 14 px on the physical right even on Android; settings Appearance has a second spacer after a section component that already supplies its gap | Shared directional editor inset retains desktop scrollbar clearance and gives Android symmetric gutters; remove duplicate settings gap; token-based agenda card/action spacing | FIXED_VERIFIED: host layouts; actual Android editor/settings base and 200% IME sample |
| F02 / B | P2 | Mobile agenda uses `const Icon(Icons.event_outlined)`; storage/controller/native Android projection already retain explicit/category colors. Custom icon is also ignored | Read `effectiveEventColor` and `iconName`; preserve the selected tint with a contrast-aware backing, including white/light and black/dark | FIXED_VERIFIED: saved custom icon/colors, inherited white contrast host test; actual rose selection/save/agenda/reopen |
| F03 / C | P2 | Event/session start callbacks update start alone; all-day start resets a multi-day end to one day | Shared draft-only duration shift; calendar-day arithmetic for all-day intervals. End edited during this session stays fixed; invalid explicit end offers visible repair. Task plan/deadline remain independent | FIXED_VERIFIED: midnight/year/date crossing and explicit end/repair; actual Android event moved Nov 2→3 with 9–10 AM interval retained |
| F04 / D | P2 | Four mobile settings selectors still use selected-item-centered `DropdownButtonFormField`, unlike other shared form controls | Reuse `AnchoredSelectField` for predictable below-trigger placement with edge fallback | FIXED_VERIFIED: settings geometry/selection, shared edge/keyboard tests; actual Android Theme menu below trigger and dark selection |
| F05 | P2 | Shared select's FormField keeps internal value when a parent changes initialValue (refreshed preferences or editor scope changed) | Synchronize changed external value without replacing the field/focus/scroll identity | FIXED_VERIFIED: external update test; no claim that an unchanged external value automatically rolls back a failed optimistic save |
| F06 / E | P2 reported | Bottom-error jumping was not reproduced in the focused editor test. Existing editors have stable list keys/controllers; recovery IME reveal runs for focus/metrics, not every error rebuild | Repeated error frames retain scroll (±1 logical px), focus and notes; no speculative offset/timer fix | NOT REPRODUCED in tested case; original device/sequence still NOT_TESTED. Native error+IME transitions remain a gap |
| F07 | P1 | Custom event-color dialog has a fixed-height Column, fixed-width segment labels and only a scrolling inner picker; 320×540/200% text reproduces 256 px vertical overflow | Let the dialog own scrolling and let picker choices wrap; keep HEX errors and actions reachable | FIXED_VERIFIED: stressed valid/invalid HEX host test and prior desktop cancel test |
| F08 | P1 | Focus dialog reserves a fixed header above an Expanded log; at 360×640/200% text status/work-log rows overflow and actions fall outside the viewport. Nested manual entry has no scroll owner | One lazy sliver scroll viewport for timer controls/log entries, flexible status and wrapped log actions; scrollable manual-work dialog | FIXED_VERIFIED: actual controls reached through scrolling, manual entry/notes above synthetic IME; existing timer start/pause/log test passes |
| F09 | P2 | All-day End displays the inclusive last day but opens its picker on the exclusive stored end, then adds another day even when accepting unchanged | Open on the displayed calendar day; preserve exclusive storage and multi-day duration | FIXED_VERIFIED: picker opens Jan 2 for Jan 3 exclusive boundary; accepting and saving leaves Jan 3 |
| F10 | P1 | Shared icon picker fixed-height input/grid overflows by 41 px at 320×540/200% with IME | One dialog scroll owner; wrapping 52 px icon targets, no intrinsic-layout callback or nested scroll viewport | FIXED_VERIFIED: short/large-text/IME host case and real icon selection/save/agenda host case |
| F11 | P2 | Actual Android Habits/Goals screens highlight Today in bottom navigation although Today is not the current view. Phone bar coerces an unpinned selection to index 0; tablet rail already uses no selection | Add a fixed More destination that opens the existing drawer and represents unpinned views. Retain 3/4 saved pinned destinations; explain this in navigation settings | FIXED_VERIFIED: red/green navigation test, 24 follow-up tests; actual final More selection captured on Statistics after hot reload |
| F12 | P3 | Habit editor's numeric recurrence label is long and ellipsizes at ordinary phone width (`Repeat every N days, weeks, months, or y…`) | Concise Repeat interval label; full unit guidance moves into wrapping helper copy | FIXED_VERIFIED: existing habit/editor compact layout checks; final native re-open not captured because harness installation closed Driver |
| F13 | P2 parity gap | Native Windows `WidgetCalendarItem` has no per-event color/icon fields and `DrawItemMarker` paints generic kind markers with widget text color. Flutter desktop and Android are separate render paths | Track native event customization parity separately; preserve existing widget appearance precedence. Requires native projection/paint tests and physical shell/DPI acceptance (unavailable here) | Open; source confirmed, no native implementation changed and no all-widget color parity claim |
| F14 | P2 suspected | Two inspected 100% native Android harness PNGs appear to clip the beginning of footer text at the left screen edge. Compact 200% sample retains readable wrapped footer. Harness checks vertical bounds, not glyph-left clipping | Next probe: record footer global/text-layout bounds and repeat in a launcher host; establish whether test-window geometry or product rendering owns it before patching | INSPECTED_FAIL for sample appearance; root cause unconfirmed, not corrected speculatively |

## Test invocation ledger

Source in these rows is `f7954d4` plus this task's working diff unless stated.
Logs keep exact tool output; failures and fixture corrections are retained.

| ID | Invocation / purpose | Actual result | New/rerun reason |
| --- | --- | --- | --- |
| T01 | Git status/branch/log, scoped source/nav/class/consumer searches, relevant guidance/receipt reads | Clean baseline; dedicated local branch created. Initial sandbox Git branch write denied, then approved escalation succeeded | New ownership/inventory |
| T02 | DTD list/connect to workspace daemon, roots add | Connected; no running apps initially. Root registered | New tooling discovery |
| T03 | Dart MCP package grep for scaffold geometry | First invalid unregistered root; after registration package path encoded SDK space as `%20`, file unavailable. Scoped local SDK read used | New diagnostic, no dependency/source changes |
| T04 | `adb devices -l`; emulator AVD inventory | No attached device initially; existing isolated AVD definitions located under ignored build logs | New environment discovery |
| T05 | `flutter test --no-pub --concurrency=1 --reporter=expanded test/stage2_ui_regression_test.dart` → baseline.log | No test output under sandbox; interrupted. Not baseline defect evidence | New; SDK cache permissions prevented launch |
| T06 | `flutter --version`; `dart --version`; direct SDK executable/version and process/lock diagnostics | Dart 3.13.5, Flutter 3.47.7. Sandbox launcher stalled; direct Flutter reported cache lock permission failure. Approved SDK access enabled checks. First process metadata probe denied; escalated read succeeded | Diagnose before retry, no SDK modifications |
| T07 | Same focused `flutter test` → targeted-01.log | 6 failed: fixture double-disposed provider-owned controller; agenda scroll finder ambiguous. Frame checks showed no scroll motion; repeated Save was obstructed by the existing snackbar | Rerun after SDK permission correction; fixture errors diagnosed |
| T08 | Direct installed `dart.exe format` on eight changed source files and new regression test | Nine files formatted successfully | New formatting |
| T09 | Dart MCP `analyze_files` on eight sources/new test | No errors | New connected analyzer |
| T10 | Focused test → targeted-02.log | PASS: 6 tests | Rerun: fix provider ownership, explicit agenda reveal and allow natural snackbar dismissal |
| T11 | Expanded focused file → auxiliary-baseline.log | 7 pass / 2 fail: confirmed F07/F08 layout overflow | New stressed-dialog probes; source red states recorded |
| T12 | `flutter test --no-pub --concurrency=1 --reporter=expanded test/stage2_ui_regression_test.dart test/anchored_select_field_test.dart test/event_editor_layout_test.dart test/session_editor_layout_test.dart test/time_tracking_widget_test.dart test/mobile_workspace_test.dart test/mobile_editors_test.dart` → feature-01.log | 41 pass / 1 fail: manual-work test's old `ensureVisible` cannot find a now-lazy offscreen child; no remaining render exception at that step. Finder changed to scoped scrolling | Rerun after F07/F08 fixes; existing shared/menu/editor/mobile regression coverage |
| T13 | Isolated `flutter run --no-pub -d windows -t lib/driver_main.dart` → windows-live.log | Debug build PASS (82.6 s); running VM PID/profile verified, synthetic task saved. APPDATA/LOCALAPPDATA printed before launch and Drift isolate confirms audit database | New actual Windows UI; no native/source/Release behavior modified |
| T14 | Existing emulator `-avd Stage2Audit -port 5586 -no-window -no-snapshot -no-audio -gpu swiftshader_indirect -memory 1536` | Fresh task-local AVD (copied configuration only), initial offline state followed by boot-completed=1; no preexisting app installed. WHPX available. CPU feature/port-range warnings retained | New isolated Android environment; no existing AVD opened/reset |
| T15 | Node/Computer Use and CUA initialization | BLOCKED: both report `failed to write kernel assets` / system path missing. Used purpose-built Flutter Driver for available Windows inspection instead | New runtime tooling probe; no tool/dependency installed |
| T16 | VM connect, Driver health/tree/screenshots and synthetic task create; settings/theme/week-start/menu/backups/sync/widget/Hotkeys navigation | Observed selected screenshots at 1264×681, dark/light. Driver menu frame-sync wait timed out; disabling frame sync allowed selection. Wrong/ambiguous close/page finders logged. Further Task Preferences route had NEEDS-LAYOUT and no completed foreground render | New actual runtime sample; nested unrendered UI stays unverified |
| T17 | Three Windows `hot_reload` calls; runtime error reads | Reloads PASS. Recorded errors came from Driver guard/finder failures. No blanket runtime-clean claim. Final isolated PID closed after verifying executable/VM profile | Rerun for additional source corrections; desktop automation unavailable for native focus recovery |
| T18 | Android `flutter run --no-pub -d emulator-5586 --flavor github -t lib/driver_main.dart --dart-define=GOOGLE_DRIVE_ANDROID_ENABLED=false` → android-live.log | In progress; only this disposable emulator targeted. Existing JDK21/SDK/Gradle/CMake cache paths reused | New Android current-source debug runtime; no cloud/account activation |
| T19 | Gradle process/daemon/thread diagnostics; version/boot/path probes | Build active in cached JAR/class loading, no download deadlock established; diagnostics retained. Initial PowerShell UTF-16 output needed `Get-Content` rather than default rg decoding | New slow-build diagnosis; no cache deletion/rebuild loop |
| T20 | `flutter analyze --no-pub lib test integration_test test_driver` → analysis.log | Pending | New integration-level analysis for shared select and dialog changes |
| T21 | Direct Dart formatting after added fixes/tests; `git diff --stat`, affected diff, `git diff --check` | Formatting and whitespace pass; only intended presentation/test/docs files | Rerun because source/tests changed after T08/T09 |
| T22 | Expanded focused file → targeted-03.log | 11 pass / 4 fail: confirmed icon picker overflow; three fixture failures from tapping before post-scroll layout or searching an offscreen lazy field. Captured notes controller and pumped completed layout | Rerun after new edge cases and explicit-end/all-day/picker scenarios |
| T23 | Expanded focused file → targeted-04.log | 13 pass / 2 fail: icon picker `LayoutBuilder` cannot provide intrinsic dimensions when a search changes its contents; next test affected by failed teardown. Replaced callback/grid with bounded wrapping buttons | Rerun after F10 first correction; regression diagnosed, assertions retained |
| T24 | Expanded focused file → targeted-05.log | PASS: 15 tests, 24 s. Includes real picker selection → repository read → agenda, explicit End preservation/repair, inclusive all-day picker, midnight/year crossing, inherited white contrast, settings menu geometry, dialog IME and validation frame/scroll/focus/draft checks | Rerun after removing intrinsic-layout conflict; final focused source |
| T25 | Final `flutter analyze --no-pub lib test integration_test test_driver` → analysis-final.log | PASS: no issues (34.2 s). T20 initially reported two redundant null assertions after promotion, now removed | Rerun because additional source fixes invalidated T20 |
| T26 | Android DTD/VM/health/profile inspection, two hot reloads after fixes | Connected; reloads pass; SQLite isolate resolves `/data/user/0/io.github.hik4.todorbit/files/TodoPilot/life_manager.sqlite`. No runtime errors in post-reload read | New real emulator current-source check; APK build completed in 872 s plus 6.8 s install; existing Kotlin/SDK warnings retained |
| T27 | Android Driver: Calendar → Event; enter synthetic title; choose Rose; Save; reopen; move Start via input date Nov 2→Nov 3; Save; select Nov 3 | PASS: rose marker visible in actual agenda; reopened event retained color; start/end remain 9–10 AM on Nov 3. Selected Rose menu text top 462 vs trigger bottom 448 logical px; no additional positioning patch justified | New native Android flow; initial Driver timeouts/early pre-paint screenshots are not passes |
| T28 | Fresh-emulator font scale=2, native keyboard enabled, Driver text-entry emulation disabled, focus event title; native `dumpsys input_method` and ADB screenshot | PASS sampled geometry: `mInputShown=true`, `mIsInputViewShown=true`; focused title and Save remain above real keyboard. `android-event-ime-2x.png`. Initial keyboard probe was false while Driver emulation was active; corrected that condition. Font/keyboard preference restored to 1/0 afterward | New actual OS IME/font case, distinct from synthetic host insets |
| T29 | Android drawer → Settings, open Theme selector → dark; Habits/New habit/cancel, Goals/New goal/cancel | Actual light/dark settings/menu and empty/editor samples observed. F11 wrong bottom selection and F12 ellipsized interval label found. No habit/goal records created | New auxiliary runtime sample; screenshot timing reconciled with widget/native tree, not inferred from immediate transition frames |
| T30 | `flutter test --no-pub --concurrency=1 --reporter=expanded` → full-host.log | PASS: 593 tests / 1 existing opt-in skip, 19m50s. Frozen source hashes checked (12 changed Dart files) and committed as `cc20582`; docs advance independently. Existing Drift multiple-instance and one workspace drag hit-test warning retained, no test failures | New integration gate because shared select/icon controls affect many screens; not a release/package gate |
| T31 | `python tools/dev/check-docs.py docs/UI_UX_STAGE2_AUDIT.md docs/PROGRESS.md` | PASS: 0 errors | New receipt/checkpoint links; final edited docs will be rechecked |
| T32 | `tools/dev/native-self-test.ps1 -Executable build/windows/x64/runner/Debug/TodorbitWidget.exe` → native-self-test.log | PASS; current Debug-bundle companion, independent random child APPDATA/LOCALAPPDATA printed. Not a Release/physical shell check | New native audit supplement; native source unchanged, no extra native rebuild |
| T33 | Explicit Git staging, staged whitespace/stat review, `git commit -m "fix(ui): refine calendar drafts and mobile dialog behavior"` | `cc20582`; 12 intended code/test paths. Audit docs remained separate | New verified implementation checkpoint |
| T34 | `flutter test --no-pub --concurrency=1 --reporter=expanded test/mobile_workspace_test.dart --plain-name 'unpinned mobile view'` → nav-baseline.log | Expected FAIL: no More destination; actual last pinned item Upcoming and fallback Today selection | New red reproduction of actual runtime F11 |
| T35 | `tools/dev/verify.ps1 -Mode Quick -ChangedPaths @('lib/features/mobile/mobile_workspace.dart','lib/features/mobile/mobile_settings.dart','lib/features/habits/habit_editor.dart') -Tests @('test/mobile_workspace_test.dart','test/habits_widget_test.dart','test/remaining_dialog_layout_test.dart')` → followup-verify.log and `.buildlog/verify/20261102-202635-6984/result.json` | PASS: formatting, clean analysis, 24 tests, whitespace | New F11/F12 follow-up; T30 retained for unchanged boundaries rather than repeating the full suite |
| T36 | Same single navigation test with labeled/Android tap-target guideline assertions → nav-accessibility.log | Guideline/actions pass, but fixture fails at end because this SDK verifies semantics handles before addTearDown runs | Rerun: new accessibility assertions; corrected cleanup ownership rather than weakening criteria |
| T37 | Same single navigation test → nav-accessibility-final.log | PASS: labels and Android touch targets at 320×640/1.5×; semantics handle disposed in finally | Rerun after fixture cleanup correction; no app source changed since T35 |
| T38 | Android hot reload after F11/F12; actual More selection screenshot and tap | Reload PASS; `android-nav-before.png` / `android-nav-after.png` show corrected Statistics selection. Subsequent Driver probes stopped when harness in-place installation closed the old app | New final navigation runtime sample; drawer action verified by T35/T37, no post-install native interaction claim |
| T39 | `tools/test-android-widgets.ps1 -Device emulator-5586 -ApplicationApk build/app/outputs/flutter-apk/app-github-debug.apk -AndroidSdk <existing SDK> -JavaHome <existing JDK21> -GradleUserHome <existing cache>` → android-widgets.log | PASS: build 5m41s, in-place installs, instrumentation code -1; 72 native captures, geometry and one-use capability checks. Only this disposable AVD; fixtures restored in finally, SQLite never opened | New native Android coverage. App APK is the earlier bootstrap debug build; native rendering code unchanged. Flutter live source after reload is distinct evidence |
| T40 | Copy/view three generated native PNGs (Calendar dark 180×180/12/200%, Tasks light 380×540/1/100%, Calendar light 280×280/1/100%) | Reviewed native images; compact case readable, suspected footer-left clipping F14 in 100% samples. Three copies in widget-renders; all 72 originals remain app-private cache | New visual review beyond automated footer-bottom assertions; no OEM/launcher acceptance implied |
| T41 | Hash three audit binaries/APKs; inspect helper receipt | Artifact SHA-256/native source tree in artifacts.json. Initial helper receipt filename `receipt.json` was absent; actual helper output is result.json and was read | New artifact identity/receipt diagnostic, no source/runtime change |
| T42 | Explicit stage/review/whitespace and follow-up commit | `69acf07`, four intended paths: mobile workspace/settings, habit editor, mobile regression test | New local Conventional Commit after T35/T37, no remote operation |
| T43 | Direct installed Dart format check across 15 affected Dart paths; `python tools/dev/check-docs.py docs/UI_UX_STAGE2_AUDIT.md docs/PROGRESS.md`; `git diff --check` | PASS: no formatting changes, 0 documentation errors, no whitespace errors | Rerun: final follow-up source/test and final audit/checkpoint content |
| T44 | Fresh AVD font/IME preferences verified 1.0/0; emulator process command/PIDs verified as Stage2Audit/port5586 before shutdown | Only the created disposable AVD targeted; profiles, synthetic data and PNG/log evidence retained. No old/personal AVD cleanup | New task cleanup after native instrumentation |
| T45 | Final documentation checker, diff/whitespace review, process and ADB inventory | PASS: final links valid, no whitespace errors; audit emulator guest/parent gone and no ADB devices attached. Only two documentation files left for the final local documentation commit | Rerun after final report/checkpoint sections; code checks remain valid |

## Result and remaining acceptance

Eleven grouped findings are fixed and verified in the stated scope. F06, the
original shaking sequence, was not reproduced. F13 is an open independent
Windows-widget parity gap; F14 is a suspected native Android capture/render
issue requiring a bounds/launcher probe before a product fix. These are not
silently counted as fixed. The sample does not establish exhaustive defect
detection, physical OS acceptance, release readiness or accessibility compliance.

Main implementation `cc20582` passed the full 593-test host suite (one opt-in
skip) and full analysis. Follow-up `69acf07` passed the explicit 24-test group,
analysis/formatting/whitespace and the additional single navigation accessibility
case. Unaffected full-suite evidence is retained; there is no claim that the
whole suite was rerun after the small follow-up. Native Windows Debug companion
self-test and Android 72-case instrumentation are supplementary evidence.

No production binary, installer, account, release, version, schema or backup
compatibility change is delivered. The Android bootstrap debug APK and its
later live hot-reload source are explicitly distinguished. Native harness
reinstallation closed that live Driver connection; its geometry/capability
checks exercise unchanged native render code, not the final Flutter navigation.

## Executed coverage and gaps

The inventory is broader than the executed matrix. This matrix is the authority
for the named checks; a sample does not pass all variants of its surface family.
All rows are applicable unless noted otherwise.

| Case / inventory IDs | Environment and check | Execution status / evidence |
| --- | --- | --- |
| R01 / S01–02 | Windows debug, 1264×681, default dark; empty Today → create/save synthetic task → populated Today; task details layout | INSPECTED_PASS in this sample; actual Driver render and saved task, windows-live.log |
| R02 / S19–21/S37 | Windows light/dark Settings; Appearance; Navigation/Calendar; open week-start menu and select Monday | INSPECTED_PASS in sample; actual below-trigger screenshot and selection; host keyboard/edge cases separate |
| R03 / S23/S26–28/S32 | Windows settings parent pages: Notifications, local/disabled Drive backups, disconnected Sync, both disabled widget controls | INSPECTED_PASS for displayed parent/disabled states; connected/cloud/native widget interactions NOT_TESTED |
| R04 / S22 | Windows nested Hotkeys default/search/list/footer | INSPECTED_PASS for visible render and Done dismissal; no shortcut rebinding claimed |
| R05 / S21 | Windows nested Task Preferences foreground after opening | BLOCKED for visual acceptance: Driver reported an unlaid-out foreground route; native activation/Computer Use unavailable. Tree inspection is weaker evidence |
| R06 / S01/S09 | Android API 35 x86-64 fresh AVD, 1080×2400 physical, density 420 (~411 logical width), base text/light; Today and empty/populated calendar week | INSPECTED_PASS sampled render/navigation; actual native and Driver screenshots |
| R07 / S06/S09 | Same Android: create Rose event, save, agenda, reopen, date-change/save | FIXED_VERIFIED F02/F03 in actual runtime; Android native launcher projection/closed-app flow separate |
| R08 / S06/S37 | Android text scale 2.0 + actual keyboard; event title focus, field/footer clearance | INSPECTED_PASS for this geometry/input state; native screenshot and IME flags. Other fields/error transitions NOT_TESTED natively |
| R09 / S19–21/S37 | Android Settings Appearance, Theme menu below field, dark selection | FIXED_VERIFIED F04 sample; stored preference round-trip/other selectors covered by host suite rather than all visually visited |
| R10 / S14–15 | Android dark empty Habits/Goals and new editors, cancel | INSPECTED_PASS for base render/cancel; F11/F12 discovered here and subsequently corrected (R19/T35). No populated history/milestone flows claimed |
| R11 / S02/S06–07/S09/S16/S19/S37 | 15 new host unit/widget tests: draft dates, UI→store→calendar color/icon, white/category inheritance, controlled selector, menu geometry, dialog overflow/IME | FIXED_VERIFIED for asserted contracts. Ahem/host rendering is not Android/Windows OS rendering |
| R12 / S38 | Host 390×540/2×, notes retained, scrolled editor, two invalid saves and 10×40 ms frames per error; natural snackbar dismissal | INSPECTED_PASS for unchanged offset/focus/draft; does not establish the user's unrecorded shaking sequence was fixed |
| R13 / shared consumers | Existing selector keyboard/Escape/focus, below/edge placement; event/session layouts; timer start/pause/log; mobile narrow/tablet/RTL/dark and unsaved/deep-link tests | INSPECTED_PASS in feature-01 for 33 existing tests; the only failed row there was a new fixture corrected by T24 |
| R14 / all inventory | Route/class/dialog/native adapter inventory and all 28 catalog applicability checks | INSPECTED_PASS for source discovery only. Unvisited nested states are NOT_TESTED, not visual passes |
| R15 / S33–35 | Real Windows widget shell/input/DPI/multi-monitor/menus with main app closed | BLOCKED for physical acceptance: desktop automation kernel unavailable; no native code changed. Historical receipts retained for their own artifacts only |
| R16 / S36 | Android native RemoteViews: both widgets × 3 sizes × 0/1/12 rows × light/dark × 100/200% text | INSPECTED_PASS for 72 executed geometry/capability captures; three images visually reviewed, with separate F14 concern. Not actual launcher/OEM placement |
| R17 / S24/S27–31 | Actual biometric/OS grant, real Google authorization/pairing/recovery, installer/update approval, personal backup workflows | NOT_TESTED. UI/source/host failure paths do not establish external/native operations; no accounts or personal data used |
| R18 / all | Physical Android ARM64/OEM launcher/rotation breadth, Windows 10, actual TalkBack/Narrator and performance traces | NOT_TESTED; no device-wide/accessibility/performance certification |
| R19 / S01/S14–17 | Final Android Statistics with fixed More state after reload; host More→drawer→Tasks at 320×640/1.5× | FIXED_VERIFIED F11; before/after native images and public-input host assertions. Native drawer action not re-observed after harness installation |
| R20 / S01/S37 | Host narrow navigation screen; labeledTapTargetGuideline and androidTapTargetGuideline | INSPECTED_PASS in named case; no broad contrast or screen-reader certification |
| R21 / S33–35 | Current Debug-bundle native companion `--self-test`, isolated child profile | INSPECTED_PASS for self-test assertions; not a native Release build or physical shell/DPI gate |
| R22 / S34 | Native Windows calendar projection/marker source | INSPECTED_FAIL F13 parity gap; independent generic markers do not carry individual event icon/color values |
| R23 / S36 | Three native Android PNG samples inspected at recorded sizes/themes | INSPECTED_FAIL for suspected F14 footer-left appearance in two 100% samples; automated vertical checks passed, root cause remains unconfirmed |

No Cartesian-product coverage claim follows from this sample. Representative
host layouts include 320×640/base, 390×844/1.5× RTL/dark and 840×500/1.3×,
plus changed dialogs at 320×540 or 360×640/2× and 240/260 px synthetic IME.
Native Android 2× uses the real OS scaling/IME and is recorded separately.

## Visual and accessibility evidence

The native Android before/after navigation images show Statistics with Today
incorrectly selected, then More correctly selected. The event/IME captures show
the symmetric editor gutters and real keyboard clearance at 2×. Actual rose
agenda rendering was inspected through Driver, with the date-change result also
checked in the live widget tree. Windows dark/light screens and nested Hotkeys
were inspected in the session. Some immediate Driver screenshots were pre-paint
transition frames and were not accepted as the final screen.

Full before/after pixel baselines for every changed surface were **NOT CAPTURED**.
The dialog failures have executed red/green geometry evidence instead. No new
goldens with host Ahem glyphs were represented as visual design acceptance.
Three of the 72 native widget PNGs were visually inspected, not all 72; the
automated geometry/capability assertions ran for all cases.

Accessibility evidence is limited to existing keyboard focus/Enter/arrows/Escape
selector tests, enlarged text/reflow, configured icon contrast, and the executed
label/touch-target guidelines on one narrow navigation screen. Real TalkBack,
Narrator, high-contrast/DPI and complete application contrast scans remain
unverified. No WCAG or native accessibility certification is claimed.

## Changed files and local handoff

| Group | Changed repository paths |
| --- | --- |
| Draft intervals/editors | `lib/features/calendar/event_editor.dart`, `lib/features/calendar/session_editor.dart`, `lib/features/shared/draft_interval.dart` |
| Mobile rendering/settings/navigation | `lib/features/mobile/mobile_calendar.dart`, `lib/features/mobile/mobile_settings.dart`, `lib/features/mobile/mobile_workspace.dart` |
| Shared controls/layout | `lib/features/shared/anchored_select_field.dart`, `lib/features/shared/app_spacing.dart`, `lib/features/shared/event_color_picker.dart`, `lib/features/shared/icon_picker.dart` |
| Auxiliary editors | `lib/features/workspace/task_editor.dart`, `lib/features/time_tracking/time_tracking_dialog.dart`, `lib/features/habits/habit_editor.dart` |
| Regression tests | `test/stage2_ui_regression_test.dart` (15 cases), `test/mobile_workspace_test.dart` (new navigation case with accessibility checks) |
| Durable audit/checkpoint | `docs/UI_UX_STAGE2_AUDIT.md`, `docs/PROGRESS.md` |

Branch `fix/stage2-ui-quality`; implementation commits `cc20582` and `69acf07`.
The documentation commit contains this final ledger and checkpoint. Seventeen
paths in total; no unrelated changes, generated output, secrets, versions,
dependencies, schema/data/cloud services, native implementation or release files.
No remote push/merge/release operation was performed.

Detailed logs, per-command helper receipt, source/artifact hashes and selected
PNGs remain ignored under `.buildlog/verify/stage2-ui/` (helper result at the
T35 path). Windows debug process and the newly created Stage2Audit emulator were
closed; final ADB inventory is empty. The fresh profiles and synthetic event/task
data remain on disk. Previous AVDs and personal profiles/backups were untouched.

Next acceptance: reproduce the original shaking sequence with exact form/input
state; investigate F14 native footer bounds in a launcher; decide native Windows
event-color/icon precedence and implement F13 with Release/self-test and physical
shell/DPI checks. Unvisited nested/connected/native states remain as listed above.

## Catalog applicability and investigation map

All categories were considered against actual Flutter/native surfaces, rather
than treating each catalog bullet as an observed defect. Web CSS/browser-only
repairs are N/A here. This table records applicability and where evidence belongs;
it does not turn a source hypothesis into a runtime pass.

| Category | Applicable probes / result or limitation |
| --- | --- |
| 01 Typography/hierarchy | Existing shared type roles and helper colors inspected; long/large text in editors/dialogs. F07/F08 are layout defects, not a new type system |
| 02 Spacing/alignment | F01: shared Android editor gutter and duplicate section spacing; agenda card/action rhythm |
| 03 Colors/themes | F02: trace picker → draft → repository → controller → mobile icon; category inheritance and contrast backing; native Android accent projection retains configured value |
| 04 Responsive density | Narrow/short/landscape/large text host matrix, including F07/F08; physical foldables/multi-monitor not tested |
| 05 Overflow/scroll | Repeated error frames/offset/focus/draft, one scroll owner in repaired dialogs; F06 root cause still unconfirmed |
| 06 Controls | Real save/result checks, busy/disabled handlers, shared select keyboard tests; F05 external value update |
| 07 Forms | F03/F09 draft intervals and inclusive date presentation; separate task planned day/deadline, actual work and optional task dates preserved |
| 08 Overlays | F04 settings menus; existing shared edge/keyboard menu tests; nested event color/icon/date/time and manual-work dialogs; unavailable native focus noted |
| 09 Navigation | Desktop/mobile route/drawer inventory, synthetic task create, mobile deep-link and unsaved Back host tests |
| 10 Icons/assets/data | F02 also repairs ignored custom icon; unchanged branding assets and truthful report values located; native icon/marker roles are distinct |
| 11 Collections | Task filter/sort, calendar agenda/grid, log lazy list, saved views and empty states; no large-data performance claim |
| 12 State feedback | Save only follows awaited controller result; existing async error/finally paths; F06 repeated validation probes |
| 13 Accessibility | Semantic selected/expanded/disabled roles and labels, existing keyboard tests, large text and marker contrast. No physical TalkBack/Narrator certification |
| 14 Motion | Frame-by-frame validation checks; no new animation. Driver frame/activation limitation remains distinct from app defect |
| 15 Copy | Interval assistance explains fixed edited End and offers explicit repair; existing destructive/restore copy preserved |
| 16 Locale/RTL | Existing RTL host cases and directional new editor padding; application copy remains English. No newly promised translations or zoned/DST UX |
| 17 Mobile | Safe-area/editor/IME/Back paths, launcher widgets separate; synthetic insets are not native keyboard acceptance |
| 18 Desktop | Actual 1264×681 debug sample; native HWND/shell/DPI/physical input stays unverified |
| 19 Input | Existing select Tab/Enter/arrows/Escape, task CRUD/Back tests; physical pointer/stylus/drag breadth not tested |
| 20 Notifications | Existing projection/reminder/permission entry points located; no OS grant or actual reminder delivery performed for these UI fixes |
| 21 State/persistence | F02/F05 and repository round trips; preview/cancel and shared preference consumers identified. No schema/store reset |
| 22 Performance | Timer work log remains lazy; bounded native projections reviewed. No measured release frame/startup/battery performance claim |
| 23 Privacy/trust | Isolated storage and no account activation; lock/PIN/Before Restore flows located. Personal backups, credentials and OS security untouched |
| 24 Platform differences | Shared controller/model plus independent mobile/desktop/native renderers mapped; actual runtime status separate for each |
| 25 Shared architecture | Existing spacing/select/controller/icon registry reused; no new library/dependency or business-layer rewrite |
| 26 Extremes | Midnight/year/month, invalid input, deliberate ends, empty/long/large text, viewport/inset tests; unexecuted combinations remain gaps |
| 27 Cognitive load | Prevent default start/end correction loops; honor deliberately fixed End. Preserve feature access and existing navigation |
| 28 Agent/evidence | Inventory, red cases, failed diagnostics, rerun reasons, diff review and explicit gaps retained; no screenshot-only universal claims |

## Stage 2.1 follow-up — 2026-11-03

Clean baseline `41cd34f`; branch `fix/stage2-1-ui-verification`. Reviewed Stage 2
commits `cc20582`, `69acf07`, `41cd34f`, current guidance, relevant native/shared
consumers, and prior source/artifact receipts. This is a focused fix/verification
pass on F06/F13/F14, not a repeat application audit. Logs and temporary profiles
are under ignored `.buildlog/verify/stage21-ui/`.

### Native Windows checkpoint

F13's first divergent boundary was the native read-only projection: it omitted
`color_value`, `icon_name` and category `event_color`. The agenda then painted a
generic marker in its text color. It now carries template/occurrence explicit
colors, category inheritance and icon keys into the native agenda. Missing old
customization columns retain compatible defaults without migrating SQLite.
Tasks/sessions and aggregate grid counts keep their distinct existing meanings.

The agenda uses the same 30 built-in Material icon glyphs as Flutter plus the
default event glyph. A 5,316-byte embedded subset is generated from Flutter's
existing font with its bundled subset tool; no package or installed Windows font
is required. Regeneration script, generated registry and attribution/license are
included. Event tint is independent of widget text overrides; an inherited
default uses the widget accent. Black/white backing preserves a configured tint
when its contrast against the agenda surface is below 3:1. Other widget surface,
text, opacity, geometry, preset and profile formats are unchanged.

Release self-test verifies legacy missing columns, inherited color, occurrence
override, changed values and reopened repository, all 31 distinct nonwhite glyphs
and contrast combinations. Actual HWND lifecycle additionally verifies the real
file-watcher/debounce updates a visible calendar's projected event style and a
recreated calendar host loads that style. This is not physical pointer/keyboard,
Win+D, monitor migration, real process relaunch or wallpaper/DPI acceptance.

### Stage 2.1 invocation ledger

| ID | Command/procedure and purpose | Result / evidence | New/rerun or reuse reason |
| --- | --- | --- | --- |
| U01 | `git status --short`, branch/log and `git show --stat cc20582`, `69acf07`, `41cd34f`; scoped source/receipt/reference reads | Clean baseline; dedicated branch created | New follow-up ownership; no reset/pull/cleanup |
| U02 | `python -c` import/probe of `fontTools` | Module absent; no installation. Flutter's existing `font-subset.exe` used | New tool capability probe |
| U03 | `python tools/dev/update-native-event-icons.py 'D:/vs code/flutter'` | 31 glyphs; 5,316-byte subset and matching registry/license | New exact-glyph source generation; rerun after Unicode generator correction |
| U04 | `dotnet build experiments/widget-shell-probe/widget-shell-probe.csproj -c Release --no-restore` → native-build.log | Failed: one supplementary code point exceeds C# char; changed registry to full Unicode strings | New native build; diagnosed before retry |
| U05 | Same build → native-build-02.log | PASS, zero warnings/errors | Rerun after full-Unicode correction |
| U06 | `tools/dev/native-self-test.ps1 -Executable experiments/widget-shell-probe/bin/Release/net10.0-windows/TodorbitWidget.exe` → native-self-test-01.log | Failed; separate redirected ProcessStartInfo diagnostic found missing required category timestamps in new fixture | New isolated native check/diagnostic; product projection not bypassed |
| U07 | Same Release build → native-build-03.log and isolated self-test → native-self-test-02.log | PASS, including new projection/glyph/contrast assertions | Rerun after supplying fixture timestamps |
| U08 | Release `--capture-widgets <ignored windows-renders>` via isolated child runner → native-captures.log | PASS; light/dark icon atlases and native previews produced. Both atlases visually inspected | New render evidence; offscreen, not shell appearance |
| U09 | Release `--lifecycle-self-test` via isolated child → native-lifecycle.log | PASS: actual two Explorer child HWNDs, independent visibility/preview/reload/recreation | New current Release lifecycle evidence |
| U10 | Release build → native-build-final.log and lifecycle → native-lifecycle-final.log | PASS; added assertions for live event-style file watcher and recreated calendar host | Rerun for new lifecycle assertions; product implementation unchanged |
| U11 | Start retained disposable Stage2Audit AVD, port5586, no snapshot/window/audio; ADB boot/profile checks | Boot completed; only prior synthetic audit guest reused, no data reset | New runtime session; retained prior AVD identity/config |
| U12 | `tools/test-android-widgets.ps1 -Device emulator-5586 -ApplicationApk build/app/outputs/flutter-apk/app-github-debug.apk -AndroidSdk .buildlog/android-sdk -JavaHome <existing JDK21> -GradleUserHome .buildlog/android-gradle-home` → android-widgets-01.log | In progress. Initial shell used a literal vswhere path; Gradle still launched. Result recorded below when complete | New footer glyph/global bounds, local renders and density/size matrix; native app source unchanged |
| U13 | `flutter test --no-pub --concurrency=1 --reporter=expanded test/stage2_ui_regression_test.dart` → scroll-host-01.log | 15 pass / 3 new probe failures: two lazy-list finders after scrolling; one initial focused-field reveal | New IME/error/cursor probes; original 15 checks still pass |
| U14 | Same test file with `--name 'error with IME\|inline color errors'` → scroll-host-02.log | In progress; corrected lazy visibility and initial reveal setup | Rerun only affected probes, no speculative app patch |
| U15 | Computer Use skill/runtime `@oai/sky` initialization | BLOCKED: failed to write kernel assets, missing path | New availability check; no replacement input helper or tooling installation |
| U16 | Task-local process/log inspection and `jcmd 27420 Thread.print` → gradle-threads.txt | Gradle worker reading cached JARs, not a demonstrated deadlock; Flutter front end subsequently advanced | New bounded diagnostic before considering retry; no cache cleanup |
| U17 | Release build → native-build-captures.log; isolated `--capture-widgets` → native-captures-final.log | PASS; additional whole-calendar light/dark renders visibly show Rose music icons; both inspected | Rerun after extending only the capture fixture to show an event unobstructed by planned tasks |

Reused: Stage 2 full-source analysis and 593 host passes/one opt-in skip on
`cc20582`, plus the `69acf07` navigation follow-up and accessibility receipts.
Their Flutter implementation/dependencies are unchanged so a full suite rerun
is not required for native read-only styling and focused new probes. Native
render evidence is invalidated by F13's implementation and replaced above.

Pending at this checkpoint: Android expanded footer probe result; focused
Flutter probes and native Android keyboard/error runtime; final render review,
documentation/manual acceptance checklist and Git handoff. Original F06 remains
unreproduced; F14 remains a hypothesis until bounds and glyph checks complete.
