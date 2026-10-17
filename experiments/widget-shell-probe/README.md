# Windows shell-host experiment (not the Life Manager widget)

This tool is isolated from `life_manager.exe --widget`. Its default mode only enumerates the current desktop, `Progman`, `WorkerW`, and icon-view hierarchy using documented read-only Win32 APIs. It does not access the Life Manager database.

On the inspected Windows 11 session, `GetShellWindow()` returned a visible Explorer-owned `Progman` spanning both monitors. Its visible `SHELLDLL_DefView` child was in front of its visible `WorkerW` child; most other `WorkerW` windows were hidden and tiny. Merely parenting the widget beneath that `WorkerW` is therefore not evidence that it will be visible or clickable. This hierarchy is an Explorer implementation detail, not a supported widget-hosting API.

## Guarded attachment prototype

The separate `--attach-prototype` mode is **not to be run until its exact cross-process attachment is approved**. It will create a Life Manager-owned diagnostic surface, change that surface to `WS_CHILD`, call `SetParent(surface, GetShellWindow())`, then position *only that surface* above the shell's icon-view child. Clicking the surface opens a separate, ordinary top-level text-input popup in the same experimental process. No undocumented Explorer message, injection, hook, registry change, service, or persistent shell change is involved. It does not display or write real tasks; its purpose is to validate desktop layering and keyboard activation before any Flutter/database integration.

Risks: Explorer may redraw, reorder, or destroy the child during a shell restart; icons in the surface rectangle may be obscured while the experiment runs; cross-process parenting and shell child Z-order are undocumented hosting arrangements and may differ by Windows build, display topology, or DPI mode. The popup may still fail to activate; that is a test result, not grounds for a focus-stealing workaround.

Safe stop: close the experiment surface, close its console, or terminate only the printed experimental PID. It automatically exits after ten minutes. On exit, it destroys only its own windows. The original `--widget` process and Explorer are not modified, restarted, or killed. If the shell hierarchy does not match the inspected shape, the mode fails closed without attaching.

Build: `dotnet build experiments/widget-shell-probe/widget-shell-probe.csproj -c Release`. Read-only inventory: `dotnet run --project experiments/widget-shell-probe/widget-shell-probe.csproj -c Release`.

After specific approval for the cross-process `SetParent` action, launch from the repository root with `dotnet run --project experiments/widget-shell-probe/widget-shell-probe.csproj -c Release -- --attach-prototype`. The dark panel is intentionally labeled as a shell-host test, not as a working Life Manager widget. Click **Input...**, type/paste/edit, and press Enter; the count in the panel changes without writing any database row. Close the popup and reopen it several times, then test `Win + D`, cover the desktop with a normal app, and return. Record which of panel visibility, click delivery, popup activation, and typing actually pass. Close the panel or press Ctrl+C in its console to stop; if both are inaccessible, terminate only the printed PID. Do not restart Explorer as part of this first test.

This stage cannot validate real task CRUD, Flutter rendering, main-app lifecycle, resizing, or Explorer recovery. Those are subsequent integration steps only if shell layering and popup activation pass manually. A successful build or read-only inventory is not evidence that the attachment works.
