# Progress

## Completed

- Initial Flutter scaffold validated before development (`flutter doctor -v`, `flutter analyze`, `flutter test`).
- Repository and initial commit inspected; clean `master` at `dac3f75` before implementation.
- Initial product, architecture, design, feature, and roadmap documents created.
- Milestone 1 task foundation: SQLite schema, per-user Windows data path, category/project/task CRUD, Today and task list views, task details, sorting, light/dark appearance, and confirmation for permanent task deletion.
- File-backed persistence close/reopen test and task creation widget test pass.
- `flutter analyze`: no issues. `flutter test`: 4 passed. `flutter build windows`: Release build succeeded. The built executable started and stayed running for a smoke check; the app created its database under `%APPDATA%\Life Manager`.
- Widget feasibility prototype: separate `--widget` process, desktop HWND parenting attempt, Today/Inbox list, task entry/completion/refresh, and main-app launch. Windows build, process smoke check, and widget interaction test succeed. All 5 tests pass. `Win + D` and visibility/layering are not manually verified.
- Milestone 3 partial: calendar day/week/month views show real tasks, deadlines, and fixed events; fixed event create/edit/delete persists in SQLite schema v2. Migration test preserves v1 task rows. The existing app database upgraded from schema 1 to 2 during a Windows executable smoke check. Analyzer clean, 8 tests pass, Release Windows build succeeds.
- Planned work sessions: create/edit/delete in calendar and task details, independent manual outcomes, “Late start” and “Needs confirmation” indicators, and calendar display. Schema v3 migration upgraded the existing Windows database from v2; tasks remained intact. Analyzer clean, 10 tests pass, Release Windows build succeeds.
- Deterministic non-mutating repack calculation with weekday windows, date exceptions, fixed-event and session blocking, buffer, no-slot explanation, and deadline warning. Three domain tests added; analyzer clean and all 13 tests pass. There is no user-facing Apply action yet.
- Fixed the category/project name dialog controller lifetime: the previous controller was disposed before the closing route finished rendering, producing `A TextEditingController was used after being disposed` and secondary render-tree assertions. The field now owns its controller. An in-memory category creation regression test reproduces the original failure before the fix and passes afterward.
- Added an in-memory task-row regression test that creates one task through the UI and repeatedly hovers its checkbox, title, and actions control; one checkbox remains and no framework exception occurs in widget tests. The reported Windows-only visual duplication has not yet been reproduced or attributed to a specific cause.
- Validation for this fix: `flutter analyze` clean, all 15 `flutter test` cases pass, and `flutter build windows --debug` succeeds. Native Windows mouse replay was unavailable because desktop automation access to the app window was denied.

## In progress

- Milestone 2 requires manual desktop behavior verification; main app development continues independently.
- Milestone 3 scheduling core: persisted/editable availability, Smart Reschedule preview UI and transactional apply/history/restoration, recurrence, dependencies, and sequences remain.
- Reproduce the reported task-row checkbox duplication in a native Windows session and capture its first exception/stack; widget tests have not reproduced it.
- Widget keyboard-focus investigation: the desktop-attached window could be inspected but not activated by native automation. The runner incorrectly called `SetFocus` on `WM_ACTIVATE` even for `WA_INACTIVE`; it now focuses Flutter only on activation. A three-cycle Flutter widget test verifies that the text field can be refocused and tasks submitted after simulated app launches/lifecycle changes. The native open/close/typing sequence still requires manual verification; desktop-child activation may need further work if it fails.
- Validation for the focus change: `flutter analyze` clean, all 16 `flutter test` cases pass, and `flutter build windows --debug` succeeds. No existing SQLite data was reset or migrated.
- Added Debug-only, `--widget-diagnostics` opt-in native and Flutter focus logs under `%APPDATA%\Life Manager\logs`, with 2 MiB caps and no typed content. Native replay confirms that after closing the main app, native focus returns to the outer widget HWND while Flutter reports its text field focused. A direct `SetFocus` attempt on the Flutter child returned error 87 and was not retained. The user confirmed `Win + D` hides the current widget; a timed diagnostic trace from that action is still needed before changing desktop layering. No architectural workaround has been committed.
- Diagnostic instrumentation validation: `flutter analyze` clean, all 16 `flutter test` cases pass, `flutter build windows --debug` succeeds, and a debug widget launch produced both native and Flutter diagnostic files. The keyboard and Show Desktop defects are **not** resolved by this instrumentation.
- 2026-10-17 architecture audit: recent PID 29252 logs show Flutter `input-focus hasFocus=true` at 11:23:06 while Win32 `GetFocus`, local GUI-thread focus, and active HWND remain null; no Flutter-view `WM_SETFOCUS` or key messages follow. The widget is `WS_CHILD` of the `csrss`-owned system desktop HWND (`#32769`), so it has no independently activatable top-level window after losing initial focus. Native UI automation also fails to activate the running widget. This explains the keyboard failure more directly than a stale Flutter text-input connection. User-confirmed `Win + D` disappearance still lacks an action-timestamped occlusion trace; the same log reports visible=1, minimized=0, cloaked=0, so a simple minimize/HideWindow explanation is unsupported. Do not apply a speculative focus or Z-order workaround. Functional repair and visual redesign are pending an explicit decision on the unsupported Explorer shell-layer compatibility risk and manual Windows acceptance testing.
- Audit-only validation: `flutter analyze` clean and all 16 `flutter test` cases pass. No source or native-host behavior changed; the existing live widget process was left running, and a new Windows build was not attempted against its executable. These checks do not validate desktop input or layering.
- On `experiment/windows-widget-shell-host`, a separate .NET/WinForms shell-host probe inventories Explorer using read-only documented APIs. On this Windows 11 session, visible `Progman` spans both monitors; its visible `SHELLDLL_DefView` is above its visible `WorkerW`, while other top-level `WorkerW` instances are hidden/tiny. The guarded `--attach-prototype` creates an in-memory display surface plus separately activated top-level input popup. It neither opens nor writes SQLite. Functional task integration and all native acceptance requirements remain pending.
- The user approved that exact attachment. One run attached only the experimental child to `Progman` (PID 10364); read-only enumeration confirmed it was visible and above the icon view, but positioned on the left monitor due to a shell-relative coordinate error. The experimental PID 24416 was stopped, its child disappeared, and Explorer remained responsive. A primary-screen coordinate correction compiles but was not reattached under the stop-on-unexpected-behavior rule. The computer-use tool could not target the child, so click delivery, popup keyboard input, `Win + D`, and normal-window layering are all **unverified**. No production code or SQLite data changed.

## Not yet implemented

- Scheduling engine, recurrence, widget tray, habits, goals, timer, templates, search/saved views, backups, Trash, notifications, privacy controls, import/export.

## Environment

- Flutter 3.47.7 / Dart 3.13.5. Windows toolchain healthy. Android SDK command-line tools and license setup incomplete; Android is outside current scope.
- Widget parenting returned success, but the user observed keyboard loss after main-app closure and disappearance under `Win + D`; the native desktop integration remains incomplete. The diagnostic parent is the `csrss`-owned system desktop HWND, not an Explorer shell layer.
- Appearance choice currently resets on restart. Future planned sessions are not yet automatically retired when a task is completed early. There is no recoverable Trash; task and event deletion use explicit confirmation and are permanent.
- Future widget design task: unify widget and main-app colors, typography, spacing, icons, and light/dark theme behavior, including compact layouts. Do this after the widget's native input behavior is reliable.

## Next action

Persist and expose weekday availability/date exceptions. Then connect the tested scheduling preview to selected sessions, add transactional before/after history and restoration, and only then expose Apply. Manually verify the widget as described in `docs/features/windows-widget.md` when the desktop is available.
