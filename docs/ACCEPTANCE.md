# Windows v1.0 final acceptance record

## v1.0.6 release checkpoint (2026-10-24)

`flutter analyze --no-pub` found no issues; all 229 serial Flutter tests passed with the existing nonfatal workspace scroll hit-test warning. Native .NET and Flutter Windows Release builds passed, as did source and packaged widget self-tests. Inno Setup 7 compiled the installer. The portable ZIP passed its archive integrity check and contains the executable, widget, Flutter/SQLite runtime, update helper, licenses, and portable marker; no profile database, settings, logs, or keys were found.

A same-path disposable portable update using the locally built 1.0.5 ZIP and the new 1.0.6 ZIP succeeded: the helper restarted the app, retained the exact profile database bytes and a sentinel file, and kept a binary rollback folder. The local 1.0.5 ZIP differs from the public 1.0.5 asset, so the same check was repeated with the public package after verifying its published SHA-256 digest; it also passed. The registered installation on this Windows account was not opened or modified. Actual installer upgrade, schema migration approval in the updated GUI, physical widget/Explorer input, Windows 10, and mixed DPI remain unverified; publish as a pre-release.

The v1.0.6 pre-release is published. All four assets were downloaded and their SHA-256 hashes matched the local files and GitHub digests. The built-in selector recognized both exact package names from the live GitHub Releases API for a 1.0.5 user on the Pre-release channel; Stable ignores this pre-release by design.

## Software Updates acceptance (2026-10-24)

| Check | Status | Evidence and limit |
| --- | --- | --- |
| Release selection, exact asset, digest and redirect validation | PASS | Focused update service tests exercise semver, channels, missing digest, corrupt and short downloads, and rejected redirects. |
| Settings controls and persistence | PASS | Widget test and isolated Flutter Driver session covered navigation, version/status display, automatic-check toggle persistence, reopening, and screenshot inspection at 1264 × 681. Physical mouse and DPI behavior remain in the separate manual row. |
| Portable 1.0.4 to 1.0.5 replacement and restart | PASS | Real packaged bundles swapped at one disposable path under temporary APPDATA/LOCALAPPDATA; helper reported success and the new executable remained running. |
| Portable profile and user data | PARTIAL | The disposable schema 20 profile retained a seeded task and event plus valid appearance/custom theme, calendar, widget, and update preference values after the swap. Migration approval and full UI reading of those records remain unverified. |
| Immediate startup failure and corrupt package | PASS | An injected executable that exited immediately caused helper exit 1 and restored the prior binary; a wrong digest failed before changing the binary. Seeded task and event survived. |
| Native widget shutdown | PARTIAL | Isolated widget process accepted the exit command and exited. The helper's refusal to swap a still-running widget is tested separately; live Explorer painting and post-update widget restart are unverified. |
| Registered installer update | UNVERIFIED | The current Windows account has a real Todorbit registration at the stable AppId/path. No separate Windows user or VM was available for a safe installed upgrade, so the registered install was not modified. The helper rejected a mismatched disposable target. |
| Database migration and recovery | PARTIAL | Existing migration and backup tests verify schema 20 to 21 and pre-upgrade snapshot behavior. The real portable swap kept schema 20 untouched pending approval; a live approval and rollback flow was not exercised. |
| Physical Settings, widget, DPI, and keyboard acceptance | UNVERIFIED | Native computer control exposed no app windows. Flutter Driver and widget tests do not establish physical mouse or Explorer behavior. |

No new GitHub Release was created; the installer remains unsigned.

The 2026-10-23 calendar, sidebar, and cross-app UI audit is recorded in
[`CALENDAR_UI_AUDIT.md`](CALENDAR_UI_AUDIT.md). Its schema 21 and interface
results are newer than the historical v1.0.5 record below.
The follow-up from `e10fe1a` fixed Habit editor height, Advanced Search and
Template field gaps, and narrow select/action overflows. Isolated debug GUI
and widget tests support those changes; Release, physical DPI/scrollbar, and
Explorer widget interaction remain manual checks in the linked audit.

## v1.0.5 publication scope (2026-10-21)

This Windows x64 pre-release uses the completed Feedback Round 4 Part 1 and 2,
Feedback Round 5, native widget redesign, and final offscreen control audit.
The detailed evidence below is retained. Windows 11 is the main development and
test platform. Windows 10, live Explorer-hosted widget painting and input,
Win+D, mixed DPI and monitor edges, and actual installed upgrade/uninstall
remain unverified. The installer is unsigned. Do not infer full manual
acceptance from automated self-tests or offscreen renders.

Final candidate gates: `flutter analyze --no-pub` found no issues; all 208
serial Flutter tests passed (one nonfatal existing scroll hit-test warning);
native .NET Release built with zero warnings/errors and its source self-test
passed; Windows Release built, its packaged widget self-test passed, and the
disposable-profile single-instance/profile-isolation script passed. The native
dependency vulnerability query found none in configured sources. An isolated
Release app displayed Todorbit branding and an empty Today view. The native
widget process started but was not targetable through Computer Use, so actual
widget pixels and input remain unverified. No installed app or personal profile
was touched.

## Native widget final control pass (2026-10-21)

| Surface / check | Result | Evidence and limit |
| --- | --- | --- |
| Edit Task date fields and four choices | PARTIAL | The five user screenshots at `D:\AI_Projects\Todorbit_Widget_UI_Review_References` document overlapping date-action borders, text-adjacent dropdown arrows, and clipped/square corners in the prior editor. Two post-fix offscreen render passes in dark/light plus a custom palette show a single date outline, separate 32 px calendar/clear actions, stable trailing arrows, and rounded choice corners. Source self-test checks geometry and clearing. Native date placeholder text did not appear in `DrawToBitmap`; live placeholder and popup input are unverified. |
| Footer and compact layout | PARTIAL | Second wide render shows breathing room after Priority and no divider; 380 px narrow render shows an independent fixed footer and scroll cue. Scrolling by real input remains unverified. |
| Calendar | PARTIAL | Offscreen dark calendar render shows themed cells and month controls. Open/close, keyboard navigation, and screen-edge placement need live checks. |
| Quick Add and main Explorer widget | PARTIAL / UNVERIFIED (GUI) | Offscreen Quick Add capture shows the rounded focus outline; its native placeholder was absent in `DrawToBitmap`, so text rendering and input remain unverified. Main paint/menu code was reviewed, but no Explorer window was available to Computer Use. Old round-four screenshot is historical. |
| Functional and packaging gates | PASS (automated) | Native Release build: zero warnings/errors. Source and packaged self-test passed. Four focused Flutter tests passed. Windows Release build passed. No Flutter source changed, so analysis was not required for this pass. |

The initial screenshot path was absent; the user supplied the five images at
`D:\AI_Projects\Todorbit_Widget_UI_Review_References` afterward. The full
image also shows the former footer divider and final row pressed against it;
the corner crops show artifacts around adjacent rounded controls. These
images establish the baseline symptoms, not their technical causes or the
live result after this commit. Post-fix offscreen captures are diagnostic only;
`DrawToBitmap` does not prove live DWM, Explorer,
popup, DPI, hover, pressed, or keyboard appearance. No production profile,
installed application, or public v1.0.3 assets were changed.
The disposable live `--preview-editor` process was also started, but Computer
Use still reported no native windows; it was stopped without saving a task.

Before treating this as final visual acceptance, use a disposable APPDATA and
LOCALAPPDATA profile and perform these checks on the target Windows desktop:

1. Inspect the widget in dark, light, and a saved custom theme with empty and
   populated views. Resize from 260x230 through wide/tall sizes; review header,
   tabs, long task titles, checkbox, Quick Add, scrolling, opacity, and corners.
2. Open Edit Task at wide and 380 px widths. Tab through every field, scroll to
   Priority, hover/press the footer, open each choice list, use arrows/Enter/
   Escape, and check disabled Project after Category is cleared.
3. Type, choose, clear, and save Scheduled day and Deadline independently.
   Open the calendar near every screen edge, switch months, and verify date
   text, focus, clear hit areas, validation, and saved values after reopening.
4. Repeat the editor at 100%, 125%, 150%, and the highest available DPI on
   each available monitor. Check narrow clipping, popup placement, corner
   pixels, buttons, text scale, focus rings, and footer scroll separation.
5. Exercise Quick Add, row editing, completion, menu, lock, drag/resize, Open
   Todorbit single instance, Win+D, app privacy lock, and 0/30/70/100% opacity.
   Record screenshots and pass/fail with the checklist in `docs/windows-widget.md`.

## Native widget redesign acceptance (2026-10-21)

| Check | Status | Evidence / limit |
| --- | --- | --- |
| Editor dark, light, and 380 px narrow appearance | PARTIAL | Disposable WinForms `DrawToBitmap` renders show themed text, choice/date fields, fixed actions, and a narrow scroll cue. This is offscreen control painting, not an Explorer or DWM screenshot. |
| Date chooser dark and light appearance | PARTIAL | Offscreen native calendar renders show themed day cells, month actions, and selected day. Physical keyboard and popup focus remain unverified. |
| Form layout, keyboard actions, persistence, theme mapping | PASS (automated) | Native self-test covers wide/stacked content height, Save/Cancel bindings, accent contrast, and create/edit persistence. Existing IPC/profile/geometry tests remain passing. |
| Header icon, tabs, rows, empty copy, quick add, opacity, context menu | UNVERIFIED (GUI) | Code and native build inspected. The available computer-use surface returned no native apps; no Explorer-attached widget pixels or pointer interactions were observed. |
| Main-app activation, Win+D, dragging, resizing, layout lock, DPI, monitor edges | UNVERIFIED (GUI) | No physical Windows interaction this round. Existing self-tests cover geometry and IPC only. |

Automated gates: native `dotnet build -c Release` passed with zero warnings/errors;
source and packaged `TodorbitWidget.exe --self-test` passed; focused
`native_widget_service_test.dart` and `desktop_widget_test.dart` passed (3
tests); `flutter analyze` found no issues; `flutter build windows --release`
passed. The current release v1.0.3 was not modified, and no production profile
was opened.

Manual checks on a disposable profile: open the widget in dark, light, and a
custom theme; inspect the menu, Open Todorbit icon/tooltip, all four tabs,
populated and empty lists, long titles, quick add, hover, 0/30/70/100% opacity,
and 260x230, narrow, wide, and tall sizes. Open Edit Task at normal and limited
screen heights; test every field, date picker, clear action, choice popup,
scrolling, Tab/Shift+Tab, Enter/Escape, text selection, validation, and stale
save. Repeat Open Todorbit to confirm one main app window, then move/resize,
lock, change DPI/monitor, and press Win+D. Record actual screenshots and
pass/fail against `docs/windows-widget.md` before a release.

## Feedback round 5 acceptance audit (2026-10-21)

Status here distinguishes functional/automated evidence from actual Windows pixels. `PASS` means the stated requirement has direct interaction evidence; `UNVERIFIED` means implementation exists but the required physical UI path was unavailable. The audit was repeated after the draft-subtask disposal fix and divider cleanup.

| Requirement | Status | Evidence and remaining limit |
| --- | --- | --- |
| Inline red-underlined spelling while typing; no forced corrections or review icon | PASS | Isolated debug GUI showed a red wavy underline on `Writting teh`; controller/channel widget tests verify spans and unchanged input. Title, notes, checklist entry/edit, and subtask entry use the same controller. Physical typing in every field remains a manual check. |
| Scheduled day and Deadline side by side when wide, stacked when narrow | PASS | Both New and Edit use `TaskEditor`; debug GUI showed the two columns at 1265 px. Widget layout test covers 380/740 px and date clearing. Narrow Release pixels remain unverified. |
| Full or compact checklist/subtask text, expansion, Settings persistence | PASS | Debug GUI showed long saved checklist/subtask in both modes and Settings changed the per-profile JSON. Widget tests cover two-line ellipsis, expand/collapse, full text, narrow width, and 1.5x text. |
| Subtle Info popover opens and dismisses by icon or outside | PASS | Debug GUI showed themed popup/quiet icon state; widget test tapped the icon twice and outside. |
| Configured hotkeys trigger actions; conflict/preset/reset/persistence | PASS | Key-event widget test opened New Task and a custom Settings shortcut; binding and preset persistence tests pass. Physical keyboard use in a Release window remains unverified. |
| Major section dividers and optional planning below Subtasks | PASS | Shared task editor tree and debug New/Edit inspection show composition before Status/Priority and Estimates. Second pass removed inner subtask row dividers; focused tests reran. |
| Checklist text selects and copies without edit mode | PASS | Widget test long-pressed a real checklist row, sent Ctrl+C, and captured nonempty clipboard text. Physical mouse selection remains unverified. |
| Resources icons in one row with accessible descriptions | PASS | Debug Edit Task showed the single row; resource widget tests confirm action tooltips and behavior. |
| New Task / Edit Task visual consistency | PASS | Both use the same editor and were inspected in the isolated debug GUI, including schedule and composition. |
| Native widget padding and editor appearance | UNVERIFIED | Code changed and native Release/self-test pass; the Explorer-hosted window was not targetable for visual inspection. |
| Native widget movement, resize, lock, menu, task edit/completion, theme sync, Open Todorbit, repeated clicks, Win+D | UNVERIFIED | Round 4 math/IPC tests and native self-test pass. The packaged widget started and accepted an `exit` IPC command on the same isolated profile as the Release main app. Physical mouse, Explorer shell, and window behavior were not observed this round. |
| Release GUI in both themes and narrow/text-scale/DPI variants | UNVERIFIED | The isolated Release process started and created a disposable database, but computer control exposed no app window. Debug GUI was inspected in both themes at normal desktop width; narrow and DPI are covered by layout tests only. |
| Round 4 regression: recurrence, Smart Reschedule, calendar, focus, views, backup/restore, privacy, profile isolation, IPC | PASS | Full serial Flutter suite covers these repository and widget paths; native self-test and isolated Release startup cover executable startup. Physical native IPC/widget clicks remain unverified. |

Automated final gates: `flutter analyze --no-pub` passed; all 208 serial Flutter tests passed; 14 focused second-pass tests passed; native `dotnet build -c Release` passed with zero warnings/errors; source and packaged `TodorbitWidget.exe --self-test` passed; `flutter build windows --release --no-pub` passed; the single-instance/profile-isolation script passed with ten secondary launches; packaged native widget launch/exit IPC passed with the main app's disposable profile. A first direct widget launch without a database showed the documented "Open the main app first" error; retrying in the correct startup order passed. The full Flutter suite emitted one existing nonfatal scroll hit-test warning in `workspace_test.dart`.

Real GUI evidence: isolated debug Flutter Driver screenshots and actions covered light/dark desktop UI, New/Edit, long text, expansion, Settings, spelling, and Info. The isolated Release executable started and created its database, but the computer-control service returned no desktop app surface. No Release visual, narrow live window, native painted widget/editor, physical hover/focus, DPI, Win+D, or mouse-drag claim is made.

Manual checks on a disposable `APPDATA`/`LOCALAPPDATA` profile:

1. Launch the current `build\windows\x64\runner\Release\Todorbit.exe`. In dark and light, open New Task and an existing Edit Task. Resize to about 1265 px and 760 px, then use Windows 100%, 150%, and any mixed-monitor DPI. Check schedule columns/stacking, section order, dividers, Resources tooltips, Info open/second-click/outside dismissal, text clipping, keyboard focus, and hover/pressed colors.
2. Type `Writting teh report` in task title, notes, checklist entry/edit, and subtask title. Confirm red underlines after a short pause and no text replacement. Use a Windows account with an installed `en-US` spelling dictionary. Check disabled spelling in Settings and restart.
3. Create long checklist and subtask titles. In Task Preferences, switch Full/Compact, expand/collapse, select text directly with the mouse, Ctrl+C, and paste into another app. Restart and verify the mode persists. Repeat with larger Windows text scale.
4. Exercise each displayed hotkey on the physical keyboard: default Ctrl+N, custom Settings, conflicts, reserved keys, preset switch/reset, and persistence after restart. Confirm editors and modal dialogs do not trigger unintended workspace actions.
5. Start the main app first on the disposable profile, then `TodorbitWidget.exe --widget --app-exe <absolute path to Todorbit.exe>`. Follow `docs/windows-widget.md` steps 1–16: drag/resize/lock, right-click menu, editor form, all-edge padding, task input/edit/completion, theme/opacity, repeated Open Todorbit clicks with one app process, and Win+D. Repeat on each available DPI and monitor. Check the privacy steps there with app lock enabled.

## Feedback round 4, part 2 (2026-10-20)

Automated widget tests cover two-line checklist expansion at narrow and wide
widths with larger text, stable checklist dialog width, scheduled date layout
and clearing, Settings/Hotkeys navigation, Info dismissal, and resource actions.
The native widget menu palette is checked by its self-test. These checks do not
substitute for observing the layered widget and Windows control painting.

In the isolated 1.0.4 Release GUI at 1266 x 713, light and dark Settings,
the Widget settings pane, the narrow task schedule/checklist draft layout,
and the Today Info popover were inspected. The Info popover initially had
faint text; the final rebuilt window showed readable text after the fix.
Typing a full draft task through Computer Use was unreliable, so a saved long
checklist row was not visually verified. No production profile was used.

Manual acceptance for the local 1.0.4 candidate on disposable profiles:

1. Inspect long checklist rows in dark and light themes at a 360 px task panel
   and a wider window. Select/copy text, expand/collapse, use every overflow
   action and keyboard navigation, then edit while entering long text.
2. Create a task with Today planned, clear it, set a deadline separately,
   create draft checklist/subtasks, and confirm cancel/save behavior. Review
   completed visible/hidden preferences and each list Info description.
3. Resize Settings to a narrow window. Open every category, change theme,
   hotkeys, task preferences, notifications, widget and privacy controls;
   restart to check persisted choices.
4. Inspect native widget light/dark context menus at normal and mixed DPI,
   including keyboard selection, screen edges, opacity, lock, refresh, and
   dismissal. Open its native task editor, resize it, edit each field, and
   inspect the date pickers and validation messages.
5. Drag/resize and lock the Explorer-hosted widget, restart to verify geometry,
   check Win+D/normal-window layering, and click Open Todorbit ten times with
   the app open and minimized. Check the tooltip, focus, and one process.
6. Drag Explorer files into Resources and review spelling suggestions from the
   installed Windows dictionary. These native input paths still require direct
   GUI observation.

The referenced TodoPilot screenshots are from an older executable: current
source and the isolated Part 1 Release GUI displayed Todorbit. Internal legacy
profile names remain for data compatibility.

## Feedback round 4, part 1 (2026-10-20)

Automated checks run on disposable data. An isolated Release window displayed
Todorbit branding and a Today default in New Task. Ten secondary launches for
the same isolated APPDATA profile left one build process. A second independent
APPDATA profile ran beside it with its own SQLite file. `--appearance` opened
Customize Theme in the existing window; repeating the command left one visible
dialog. The native widget self-test passed, and read-only shell diagnostics
found a visible layered `WS_CHILD` under `SHELLDLL_DefView`. Computer Use did
not expose that Explorer child as a targetable window, so its pixels, mouse
dragging, resizing, lock, DPI, and Win+D behavior remain unverified.

Part 2 manual checks on isolated profiles:

1. Drag the unlocked widget across monitors at 100% and mixed DPI; resize from
   each edge and corner; release, restart, and confirm the exact geometry.
   Repeat with Layout Lock, Win+D, normal-window overlap, task checkbox, and
   the native editor. Confirm repaint has no snap-back or flicker.
2. Repeatedly click Open Todorbit and Customize Theme in the widget with the
   app open and minimized. Check focus, one process/dialog, and Open full
   details routing. Repeat with two independent portable extractions.
3. Use every default hotkey, record a custom combination, test duplicate and
   reserved keys, save/rename/delete/switch presets, restart, and type in
   editors and modal dialogs without unintended actions.
4. Review misspellings in title, notes, checklist, and subtask fields with an
   installed English (United States) Windows dictionary. Check suggestions,
   keep-as-written, technical terms/URLs, and the disabled preference.
5. Drag one and multiple Explorer files into task Resources; confirm target
   highlight, attach/link choice, duplicate path handling, missing/oversized
   file errors, resource labels, and portable-copy versus local-link behavior.
6. Create, edit, reorder, and cancel draft checklist items and subtasks;
   verify independent child dates, no orphan records, and Today/No Date/Anytime
   defaults. Switch completed-task display and reopen a completed task.

Spell checking is an explicit on-demand review, not inline misspelling marks.
The file-drop receiver accepts local Explorer files only. Actual native drop
input and the Windows COM dictionary result still require GUI observation.

## Todorbit 1.0.3 rebrand checkpoint (2026-10-20)

The 1.0.2 Release GUI was later enumerated in an isolated Windows profile. Its
dark and light Today views showed the outlined orbit mark and readable text.
An undated task was created, found in Anytime, and completed. The Settings
data-profile dialog showed the disposable SQLite path.

The extracted 1.0.3 portable GUI opened from a path containing spaces in a
separate temporary APPDATA/LOCALAPPDATA root. It showed the Todorbit title and
mark, began with zero tasks, created a task planned for today, displayed it on
Today, and retained it after a full restart. A second extraction in the same
temporary root opened with zero tasks and created a different location-keyed
profile. The extracted widget self-test passed. An actual installed 1.0.3
fresh start, registered upgrade, uninstall/reinstall, Windows 10, and native
widget shell interactions remain unverified. Older rows below describe their
recorded version-specific GUI evidence; do not treat them as a complete 1.0.3
pass.

## TodoPilot 1.0.2 update (2026-10-19)

The 1.0.2 Release build and packaged widget self-test pass. The final portable
ZIP's extracted widget self-test also passes. The isolated 1.0.2 GUI process
started, but the Windows inspection tool did not enumerate its window. The
transparent in-app sidebar mark is therefore present in source and package but
still needs direct dark/light visual acceptance at 24 px. Rows 2–25 and 27–29
below retain their prior manual status; the 1.0.2 installer, registered upgrade,
uninstall, taskbar/shortcut icons, widget composition/input/DPI, and Windows 10
remain untested. Do not treat the older 1.0.1 GUI observations as a 1.0.2 pass.

Status updated 2026-10-19. Tests use disposable profiles. `Passed` means this
checkpoint's actual Windows Release UI was observed. Automated tests are
reported separately in `PROGRESS.md` and do not turn an unobserved GUI flow into
a manual pass.

| # | End-to-end flow | Status | Evidence or next check |
|---|---|---|---|
| 1 | First launch | Passed | Release window opened on verified isolated APPDATA/LOCALAPPDATA; empty Today rendered. |
| 2 | Create categories, projects, tasks | Manual verification required | A task was created in the final Release app; category/project creation still untested. |
| 3 | Edit, complete, reopen, delete tasks | Manual verification required | Full Release flow untested. |
| 4 | Sequences and dependencies | Manual verification required | Full Release flow untested. |
| 5 | Reschedule preview, cancel, apply | Manual verification required | Prior narrow preview inspection; full Release flow untested. |
| 6 | Schedule Undo and restoration | Manual verification required | Full Release flow untested. |
| 7 | Recurring tasks and series editing | Manual verification required | Full Release flow untested. |
| 8 | Recurrence exceptions and collisions | Manual verification required | Full Release flow untested. |
| 9 | Habit progress | Manual verification required | Full Release flow untested. |
| 10 | Goals and task links | Manual verification required | Full Release flow untested. |
| 11 | Timers and manual work | Manual verification required | Full Release flow untested. |
| 12 | Task templates | Manual verification required | Full Release flow untested. |
| 13 | Saved views | Manual verification required | Full Release flow untested. |
| 14 | Reports and statistics | Manual verification required | Empty report was inspected at an earlier checkpoint; populated result untested. |
| 15 | Reminders | Manual verification required | Actual Windows tray delivery untested. |
| 16 | Archive and restore | Manual verification required | Partial earlier inspection; full Release flow untested. |
| 17 | Trash recovery | Manual verification required | Full Release flow untested. |
| 18 | Database export | Manual verification required | Native file picker untested. |
| 19 | Database import preview | Manual verification required | Native file picker untested. |
| 20 | Next-launch restore | Manual verification required | Native Release flow untested. |
| 21 | Managed attachment add/open | Manual verification required | Native picker and opener untested. |
| 22 | External file, folder, URL links | Manual verification required | Native picker and opener untested. |
| 23 | Missing external resource | Manual verification required | Full Release flow untested. |
| 24 | Enable, unlock, relock privacy | Manual verification required | Disabled dialog visually inspected; computer-use rules barred changing privacy settings through UI automation. |
| 25 | Widget respects lock | Manual verification required | Native self-test covers lock-state decisions; real two-process UI untested. |
| 26 | Restart and persistence | Passed | A task created in the isolated Release app retained its UUID and planned date in SQLite and appeared on Today after a full app restart. |
| 27 | Main app/widget independent lifecycle | Manual verification required | Previously accepted widget build; privacy changes require retest. |
| 28 | Theme synchronization | Manual verification required | Previously accepted widget build; final package requires retest. |
| 29 | Widget after Win+D | Manual verification required | Computer-use rules bar Windows-key automation; user must perform. |
| 30 | Packaged or installed application | Manual verification required | Feedback Round 2 Release bundle opened and its 15 files were rebuilt into the Inno Setup 7.1.0 installer; bundle audit found no database or personal files, and the packaged widget self-test passes. Installed flow remains untested. |
| 31 | New profile versus existing profile | Manual verification required | Disposable database tests pass; newly installed profile and existing personal profile need GUI comparison. |
| 32 | Recurring lecture and single-date cancellation/restoration | Manual verification required | Repository and widget tests pass; isolated Release GUI flow untested. |
| 33 | Event reminder balloon | Manual verification required | Native self-test covers one-off, selected weekday, cancellation, and duplicate claim; actual Windows tray delivery untested. |
| 34 | Task/category/project icon selection | Manual verification required | Persistence tests pass; visual size and reset behavior need Release GUI check. |
| 35 | Checklist and one-level subtask | Manual verification required | Persistence and widget tests pass; full Release GUI flow untested. |
| 36 | Progressive recurring study plan | Manual verification required | Assignment, skip, edit, restart, split, migration, and Calendar/editor tests pass; full Release GUI flow untested. |
| 37 | Focus stopwatch and sidebar mini timer | Passed | In the isolated Feedback Round 2 Release profile, focus visibly advanced from 00:00:00 to 00:00:06, the sidebar mini timer updated, Stop produced a 00:00:14 timer log and stopped state, and the task stayed In progress. Pause/resume still has automated coverage and needs a direct Release visual pass. |
| 38 | Windows title bar and application icon | Partially passed | The final extracted 1.0.1 ZIP visibly shows the transparent outlined orbit in the title bar. Resource 102 is the separate window icon; resource 101 remains the original black-tile icon. Taskbar selection, maximize/restore, DPI, shortcuts, and installer visuals need GUI checks. |
| 39 | Orbit icon in Release app | Partially passed | The primary executable ICO is byte-identical to the previous committed black-tile orbit; the rebuilt executable's extracted associated 32 px icon remains black and white. The new outlined window ICO has 16/20/24/32/48/64 px entries. Start menu, File Explorer, desktop shortcuts, and taskbar still need direct visual checks. |
| 40 | Visual color wheel and HEX | Passed | At 1266×713, the hue ring, saturation/value square, preview, HEX field, and Cancel/Reset/Confirm controls fit without overflow. Mouse wheel selection changed preview and HEX; keyboard HEX edit changed preview and wheel. |
| 41 | Separate palettes and restart persistence | Passed | In an isolated profile, light accent changed to `#BD561A`; saved settings and a full TodoPilot restart retained it while dark accent stayed `#B9A4F4`. Automated persistence test also passed. |
| 42 | Native widget opacity, layout lock, and desktop behavior | Partially passed | Initial isolated GUI launch failed to create the layered child. A Windows-aware manifest fixed creation; read-only inspection then found the visible `WS_EX_LAYERED` child under Explorer at the intended (1520,24) screen position across two monitors. Actual 0/30/70/100% alpha over wallpapers, Win+D, context menu, task hit testing, DPI resize, and independent lifecycle still need direct GUI acceptance. |
| 43 | Portable ZIP and installer | Partially passed | The final 1.0.1 ZIP has 26 entries and no database, settings, backups, logs, or keys. Two extracted copies launched in one disposable application-data root and created separate empty profiles. The Inno Setup installer compiled from the checked Release bundle; no installer installation was performed. Hashes are in `docs/PROGRESS.md`. |
| 44 | Portable persistence and separate copies | Passed | An extracted copy opened with zero tasks, fixed events, goals, habits, work sessions, timer runs, and time entries. One task created in its UI remained after reopening; a second extracted copy opened with zero tasks in a different profile. |
| 45 | Old Life Manager data on fresh start | Partially passed | The unmarked Release executable opened a fresh empty database beside a disposable legacy database with one task and offered a reviewed import. The actual fresh installer operation is untested. |
| 46 | Existing TodoPilot upgrade and widget profile | Partially passed | A disposable legacy database plus valid upgrade marker selected the one-task legacy profile in the Release app; the native widget wrote settings there. Two final packaged portable widgets ran concurrently and commands exited only the matching copy. Actual registered-installer upgrade remains untested. |
| 47 | Uninstall and reinstall | Manual verification required | Source has no personal-profile uninstall deletion. No disposable Windows user or VM was available for an actual installer/uninstaller run; data retention after that operation is unverified. |

The privacy dialog opened in the rebuilt Release app with the default disabled
state and no visible layout overflow at 1266×713. It was closed without
changing settings. A final Release UI run created a disposable Today task and
verified it after restart. No personal database was opened or migrated.

Feedback Round 2 also inspected the rebuilt dark-theme Release at 1266×713 in
a disposable profile. Today, the reorganized new-task editor, empty Calendar,
task row, live focus dialog, stopped work log, and mini timer rendered without
visible overflow. Light-theme Today and its task row also rendered with readable
contrast and matching native caption colors. A disposable task and a short timer
log were created only in that isolated profile. Narrow restored windows,
125%/150% DPI, populated secondary views, and the native widget remain manual
visual checks.
