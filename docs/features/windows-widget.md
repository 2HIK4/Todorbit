# Windows widget

Investigate an integrated native companion that stays on the desktop under `Win + D` while ordinary windows may cover it. The companion must own its lifecycle independently of the main Flutter window. Verify desktop attachment manually on actual Windows, including Explorer restart, display changes, DPI, and multiple monitors. Undocumented shell behavior is a compatibility risk. Never claim `Win + D` support based only on automated tests. Do not change startup or registry settings without explicit approval.

## Feasibility prototype

The same Windows executable accepts `--widget` and starts a separate Flutter process with a small task UI. The native runner changes that window to a child of the desktop HWND using documented `SetParent`. The process exits if parenting fails, rather than falling back to an ordinary window. This approach does not send undocumented Explorer messages or change Explorer configuration.

Run `build\windows\x64\runner\Release\life_manager.exe --widget` from the repository. The prototype can list Today/Inbox tasks, add a task, complete a task, refresh, and open the main app. Closing the main app does not close the widget process. It currently has no drag/resize persistence, timer, tray, automatic refresh, or startup behavior.

Native parenting succeeds, but the user confirmed that `Win + D` hides the widget. Diagnostics show the parent is the system desktop HWND (`#32769`, owned by `csrss`), not an Explorer `WorkerW`/`Progman` shell layer. This implementation uses public `SetParent`, but that API does not guarantee the required Show Desktop layering or keyboard activation. No undocumented Explorer messages are currently used. Do not expose this as a completed widget feature.

## Keyboard-focus verification

After the main app closes, a native replay showed `WM_SETFOCUS` returning to the outer widget HWND while Flutter's task-field `FocusNode` reported focused. The Flutter view HWND did not regain native focus, so keyboard messages were not routed to it. A synchronous `SetFocus` handoff during the outer `WM_SETFOCUS` returned error 87 and was removed; it is **not** a verified fix. The earlier `WA_INACTIVE` guard remains, but did not resolve the reported bug. Flutter widget tests cannot exercise this native routing.

The later PID 29252 trace is stronger: at 11:23:06 Flutter marked the input focused while `GetFocus`, `GetActiveWindow`, and GUI-thread focus were null, with no subsequent Flutter-view `WM_SETFOCUS` or key messages. Reparenting the Life Manager window as `WS_CHILD` of the system desktop removes its independent top-level activation path. [Windows activates top-level windows on mouse input](https://learn.microsoft.com/en-us/windows/win32/winmsg/window-features); Flutter focus alone cannot direct native keyboard messages to this process. This is an architecture defect, not evidence of a disposed `FocusNode` or stale text-input connection. Computer-use automation also could not activate the running child window, so no end-to-end keyboard acceptance test passed.

The same trace reports the widget visible, not minimized, and not DWM-cloaked while its foreground HWND changed. Those states do not prove what visually covered it during `Win + D`, because no action timestamp or shell occlusion probe was recorded. Do not claim a precise Show Desktop mechanism from this log alone.

## Opt-in diagnostic build

Build with `flutter build windows --debug`, then launch `build\windows\x64\runner\Debug\life_manager.exe --widget --widget-diagnostics`. The flag is effective only in a Debug native build and only in widget mode. Logs are written to `%APPDATA%\Life Manager\logs\widget-diagnostics-<widget PID>.log` (Win32 messages/window state) and `widget-flutter-diagnostics-<widget PID>.log` (Flutter focus/lifecycle). Each file is capped at 2 MiB; the native log rotates once to `.old`. Ordinary launches and production builds do not enable diagnostics.

The logs contain timestamps, process/window IDs, classes, style flags, focus/visibility state, and event names. They do **not** contain key codes, typed characters, task titles, clipboard contents, or text-field values. Review them before sharing because process/window metadata and local timestamps may still be sensitive.

For the needed manual trace:

1. Close any older widget process, launch the diagnostic widget, click the task field, and type a short unsaved marker. Note the time.
2. Click Open main app, close only the main window, click away and back to the widget field, and try typing again. Repeat this cycle twice more. Note when typing stops or resumes. Submit a disposable test task only if desired; the diagnostic itself does not require a database write.
3. Press `Win + D` and record whether the widget disappears, reappears on a second press, or returns when a normal window opens. Note the time. If practical, repeat after an Explorer restart and note whether the widget survives.
4. Find the two newest files with the same widget PID in `%APPDATA%\Life Manager\logs`. Share both files and the noted times. Do not include the SQLite database.

The Win32 log samples visibility, minimization, cloaking, parent, and foreground changes every two seconds **only while diagnostics are enabled**, and writes a full sample only when the state changes. It also records relevant messages on the outer widget and Flutter child HWNDs. This is observation only; there is no focus-restoration timer.

## Architecture choices pending the trace

- Keep `SetParent(GetDesktopWindow())`: both APIs are public, but the current result fails the user's keyboard and Show Desktop requirements. Successful parenting is not proof of the needed layering.
- Use a normal activatable top-level/tool window positioned low in the Z-order: this uses public Win32 APIs and should allow conventional keyboard activation, but `Win + D` may hide it. It cannot be adopted as a silent substitute for a desktop-attached widget.
- Attach to Explorer's `WorkerW`/`Progman`/`SHELLDLL_DefView` hierarchy: examples rely on undocumented Explorer window layout and messages. This may produce desktop-like layering, but is not a supported Windows API contract and requires recovery from Explorer restart, layout changes, and Windows-version differences. Do not adopt it without an explicit compatibility decision and real Windows 10/11 testing.

## Isolated shell-host experiment

Branch `experiment/windows-widget-shell-host` contains a standalone [shell probe](../../experiments/widget-shell-probe/README.md). Its default mode safely inventories existing shell windows without touching Explorer. In the inspected session, the visible `WorkerW` is behind `SHELLDLL_DefView` under `Progman`; direct WorkerW parenting would not establish clickability. A separate, guarded attachment mode puts only an experimental surface in front of that icon view and opens an ordinary top-level popup for keyboard input. This is not the production widget and does not access tasks or SQLite. Attachment was approved and tried once; no keyboard or Show Desktop success is claimed.

The approved first attachment did put only the experiment's window above the icon view. It landed on the left monitor because shell-relative coordinates were mistaken for primary-screen coordinates; the experimental process was stopped and Explorer remained responsive. A coordinate correction is built but untested. The computer-use tool could not target the attached child, so input, `Win + D`, normal-window coverage, and recovery are still manual tests, not verified outcomes. See the experiment README for exact steps and safe stop.

## Native hybrid integration candidate

The experiment now also contains an integration candidate launched with
`--widget`. It does not replace `life_manager.exe --widget`.

- The persistent display is a single double-buffered, owner-drawn native HWND
  created directly as a child of Explorer's existing `SHELLDLL_DefView`,
  positioned near the primary working area's top-right. It is not a reparented
  WinForms Form and has no persistent child controls.
- Quick Add is a separate, ordinary modal top-level window, so text input does
  not depend on activating a shell child.
- The native repository opens the existing database in read/write mode only
  when it already exists and reports schema version 3. It does not create or
  migrate the production database. Task inserts use UUIDs, UTC timestamps and
  a transaction; completion updates status, completion time and update time in
  a transaction.
- The display supports manual refresh, task completion, an empty state, opening
  the main application, clean close, duplicate-instance prevention, and dark
  (default) or light (`--light`) palettes.

This architecture still depends on Explorer's undocumented window hierarchy.
No undocumented Explorer messages are sent, and no Explorer-owned window is
moved, hidden, restyled, or destroyed. Manual acceptance remains mandatory for
desktop-attached pixel visibility, click delivery, `Win + D`, ordinary-window
coverage, repeated popup focus, multiple monitors, and Explorer restart.

Build and run from the repository root:

```powershell
dotnet build experiments\widget-shell-probe\widget-shell-probe.csproj -c Release
experiments\widget-shell-probe\bin\Release\net10.0-windows\widget-shell-probe.exe --widget --app-exe build\windows\x64\runner\Debug\life_manager.exe
```

Append `--light` for the light palette. Run the isolated persistence check with
`widget-shell-probe.exe --self-test`; it uses a temporary database and deletes
only that temporary test directory.

For controlled rendering comparison, `--widget-standalone` opens the former
WinForms UI normally and `--widget-legacy-reparent` runs the black-surface host.
Add `--render-diagnostics` to either candidate to write bounded paint/style
metadata to `%APPDATA%\Life Manager\logs\native-widget-render-<PID>.log`.
Diagnostics never record task text or keyboard input. The legacy mode exists
only for diagnosis and is not the recommended widget.
