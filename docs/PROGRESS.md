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

## Not yet implemented

- Scheduling engine, recurrence, widget tray, habits, goals, timer, templates, search/saved views, backups, Trash, notifications, privacy controls, import/export.

## Environment

- Flutter 3.47.7 / Dart 3.13.5. Windows toolchain healthy. Android SDK command-line tools and license setup incomplete; Android is outside current scope.
- Full visual UI interaction on a real desktop has not yet been manually verified. Widget parenting returned success; `Win + D` behavior and layering have not been verified.
- Appearance choice currently resets on restart. Future planned sessions are not yet automatically retired when a task is completed early. There is no recoverable Trash; task and event deletion use explicit confirmation and are permanent.

## Next action

Persist and expose weekday availability/date exceptions. Then connect the tested scheduling preview to selected sessions, add transactional before/after history and restoration, and only then expose Apply. Manually verify the widget as described in `docs/features/windows-widget.md` when the desktop is available.
