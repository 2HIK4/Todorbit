# Windows shell-host experiment (not the Life Manager widget)

This project contains the integrated native widget plus retained shell
diagnostics. Its no-argument mode only enumerates the current desktop,
`Progman`, `WorkerW`, and icon-view hierarchy using documented read-only Win32
APIs. It does not access the Life Manager database.

On the inspected Windows 11 session, `GetShellWindow()` returned a visible Explorer-owned `Progman` spanning both monitors. Its visible `SHELLDLL_DefView` child was in front of its visible `WorkerW` child; most other `WorkerW` windows were hidden and tiny. Merely parenting the widget beneath that `WorkerW` is therefore not evidence that it will be visible or clickable. This hierarchy is an Explorer implementation detail, not a supported widget-hosting API.

## Guarded attachment prototype

The separate `--attach-prototype` mode creates a Life Manager-owned diagnostic surface, changes that surface to `WS_CHILD`, calls `SetParent(surface, GetShellWindow())`, then positions *only that surface* above the shell's icon-view child. Clicking the surface opens a separate, ordinary top-level text-input popup in the same experimental process. No undocumented Explorer message, injection, hook, registry change, service, or persistent shell change is involved. It does not display or write real tasks; its purpose is to validate desktop layering and keyboard activation before any Flutter/database integration. The user approved this exact temporary attachment on 2026-10-17, subject to the stated restrictions.

Risks: Explorer may redraw, reorder, or destroy the child during a shell restart; icons in the surface rectangle may be obscured while the experiment runs; cross-process parenting and shell child Z-order are undocumented hosting arrangements and may differ by Windows build, display topology, or DPI mode. The popup may still fail to activate; that is a test result, not grounds for a focus-stealing workaround.

Safe stop: close the experiment surface, close its console, or terminate only the printed experimental PID. It automatically exits after ten minutes. On exit, it destroys only its own windows. The original `--widget` process and Explorer are not modified, restarted, or killed. If the shell hierarchy does not match the inspected shape, the mode fails closed without attaching.

Build: `dotnet build experiments/widget-shell-probe/widget-shell-probe.csproj -c Release`. Read-only inventory: `dotnet run --project experiments/widget-shell-probe/widget-shell-probe.csproj -c Release`.

Read-only placement diagnostic: `dotnet run --project experiments/widget-shell-probe/widget-shell-probe.csproj -c Release -- --inspect-pid PID`. This does **not** attach a window or change Explorer. It reports the primary-screen target and its conversion into `Progman` client coordinates, monitor intersections and DPI/scale, shell sibling order, top-level bounding-box overlaps, and—only if a direct child with that PID is still alive—its actual rectangle, styles, parent/owner, visibility/cloaking, and hit-test result. A missing PID cannot be diagnosed retrospectively. Use `--inspect-pid PID --delay-seconds 5` to take a read-only snapshot after you manually press `Win + D`; the delay is limited to 1–15 seconds. A visibility flag or successful `SetParent` is not proof that pixels are visible.

To manually test, launch from the repository root with `dotnet run --project experiments/widget-shell-probe/widget-shell-probe.csproj -c Release -- --attach-prototype`. The dark panel is intentionally labeled as a shell-host test, not as a working Life Manager widget. It should appear near the primary screen's top-left corner. Click **Input...**, type/paste/edit, use Backspace, and press Enter; the count in the panel should change without writing any database row. Close the popup and reopen it several times, then press `Win + D` and record whether the panel stays visible. Open a normal application over it and verify it is covered; return to the desktop, click the panel again, and test typing. If icons become inaccessible outside the panel rectangle or Explorer behaves unexpectedly, stop immediately. Close the panel or press Ctrl+C in its console to stop; if both are inaccessible, terminate only the printed PID. Do not restart Explorer as part of this first test.

In the first approved run, `SetParent` succeeded and a read-only inventory showed the experiment's own visible child above `SHELLDLL_DefView`, but at `(-1896,24)` on the left monitor because the initial implementation treated shell-relative coordinates as screen-relative. The process was stopped; the child disappeared and Explorer remained responsive. Positioning was then corrected using `ScreenToClient`. The user subsequently ran that corrected build and reported successful attachment of PID 22244 but no visible panel. That process was gone when inspected, so its actual rectangle, styles, and hit target are unknown. The current read-only geometry check places the intended 360×228 rectangle at `(24,24)–(384,252)` on primary `DISPLAY1` and converts it to `Progman` client point `(1944,24)`; it has no intersection with the left-hand secondary `DISPLAY5`. Both monitors currently report 100% scale. During that check, a normal Code window covered the intended point, but this does not prove it was there during the user's test. A post-attachment diagnostic snapshot is now printed by the prototype and can be queried independently by PID; **no new attachment was launched to validate it**. The computer-use tool did not expose the shell child as a targetable window, so mouse and keyboard input, `Win + D`, and normal-window layering remain unverified.

If choosing to retest manually after reviewing the diagnostic code, first build Release, then launch `--attach-prototype` in one terminal and note its PID. In a second terminal, run `--inspect-pid PID --delay-seconds 5`, press `Win + D` yourself during the countdown, then restore the terminal to read/copy the output. Look for the panel at the top-left of the **primary** display, not the left secondary. Compare `actualMinusIntended`, actual monitor intersection, sibling order, `DWM cloak`, and the center `WindowFromPoint`. If the panel is not visible, record those lines and stop the experimental PID immediately rather than retrying. Do not move or restyle Explorer windows. Manual observation is still needed to distinguish normal-window occlusion from shell compositing or a drawing failure.

This stage cannot validate real task CRUD, Flutter rendering, main-app lifecycle, resizing, or Explorer recovery. Those are subsequent integration steps only if shell layering and popup activation pass manually. A successful build or read-only inventory is not evidence that the attachment works.

## Standalone paint check

`--standalone` opens an ordinary bordered, taskbar-visible high-contrast test
window. `--standalone-capture PATH.png` temporarily raises only that test
window, captures its own screen rectangle after painting, writes the requested
PNG, and exits. This proved that the WinForms surface paints normally before
desktop attachment; it does not prove shell-child composition.

## Integrated native widget

`--widget` launches the integrated native widget. The Windows build publishes
it beside the main app as
`life_manager_widget.exe`. Its persistent display is one double-buffered, owner-drawn native
HWND created directly under Explorer's existing `SHELLDLL_DefView`; its Quick
Add editor is a temporary activatable top-level surface aligned over the
painted field. The widget reads real schema-v4 task data, supports
Today/Inbox/All Tasks/Upcoming, creates tasks with view-specific scheduling,
completes tasks, and opens a compact optimistic-concurrency task editor. It
prevents duplicate instances, shares the app's persisted system/light/dark
appearance, watches SQLite/settings changes without polling, and owns a
lightweight tray workflow. Position, size, and selected view persist per user;
all edges and corners resize and bounds are clamped to connected working areas.

The repository boundary is intentionally narrow. It refuses to create or
migrate the production database, checks `PRAGMA user_version = 4`, uses
parameterized SQL, transactions, stable UUIDs, UTC timestamps, foreign keys,
and a five-second busy timeout. `--self-test` validates creation and completion
against a disposable temporary database; it never opens the production file.

Build and launch from the repository root:

```powershell
dotnet build experiments\widget-shell-probe\widget-shell-probe.csproj -c Release
dotnet run --project experiments\widget-shell-probe\widget-shell-probe.csproj -c Release -- --self-test
dotnet run --project experiments\widget-shell-probe\widget-shell-probe.csproj -c Release -- --widget --app-exe build\windows\x64\runner\Debug\life_manager.exe
```

Use the tray Appearance submenu or a `--widget-command theme-light` command to
change the palette. Stop with the widget's Close button, tray Exit widget, or
`--widget-command exit`. Launch at sign-in is disabled unless the user checks
the tray option. The widget makes no persistent Explorer change. Explorer
hosting remains undocumented and must be manually checked for
visible pixels, clicks, `Win + D`, normal-window coverage, repeated typing,
multiple monitors, and Explorer restart before production integration.

The integrated launch commands and regression checklist are maintained in
`docs/windows-widget.md`.

The original WinForms display was painted as a top-level Form and then
cross-process reparented. Bounded diagnostics prove that it receives full-client
`WM_PAINT` messages while the user-visible surface remains black until a screen
capture. Attempting to create that Form with a foreign parent is also invalid:
WinForms moves it into a hidden parking window during `OnShown`. The default
owner-drawn host avoids both transitions and redraws only after actual state,
hover, scroll, or display changes. It has no continuous repaint timer.

Comparison modes:

- `--widget-standalone`: former WinForms UI as a normal top-level window.
- `--widget-legacy-reparent`: former post-paint reparenting behavior.
- `--widget`: current owner-drawn native shell child.
- `--render-diagnostics`: bounded message/style log under
  `%APPDATA%\Life Manager\logs`; no task text or keystrokes are recorded.
