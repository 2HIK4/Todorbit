---
name: todorbit-regression
description: Select and run risk-based Todorbit regression checks for Flutter UI, SQLite or recurrence logic, profile settings, native Windows widget IPC, updates, and installer packaging. Use when validating a code change or release checkpoint.
---

# Todorbit regression

Identify changed boundaries with `git diff` and a targeted `rg` search. Reuse nearby tests and the installed Dart/Flutter MCP analyzer, LSP, DTD, and runtime diagnostics when applicable. Run the smallest relevant test set while editing, then widen only for shared behavior or an unresolved failure. Do not claim a test covers a physical Windows interaction it did not perform.

For redesigns, apply the [design system rollout checks](../../../docs/UI_DESIGN_SYSTEM.md#rollout-and-checks). When a pane adapts to a resize, exercise a live edit draft across the breakpoint at regular and enlarged text. Verify the active field and save action remain reachable in the narrow layout. When a palette or preference changes, check applicable contrast, existing data compatibility and a save/reopen round trip.

For task lists, exercise the final row with the floating Add button and
compact toolbar. Verify the fixed editor footer leaves scrollable help and
controls reachable. Use the [task-list presentation rules](../../../docs/UI_DESIGN_SYSTEM.md#batch-2-task-list-presentation).

For a signed update, verify a persisted preference alongside task data on
the disposable emulator. A built-in palette change should cover reset,
saved explicit colors, and native fallback tokens.

For desktop Calendar performance, use the isolated Profile driver in
`docs/TESTING.md`. Reuse the populated fixture and report driver latency, UI
and raster times, sampled stacks and repeated-open heap separately. Capture
median, p95, p99, worst and missed-frame rates using the recorded refresh
budget. Keep automated layout checks alongside the independent visual review
for material polish.

For Calendar, use the `calendar-ui` selector to cover both Flutter shells.
For timeline renderer changes, exercise overlap, pointer cancellation, resize
and undo in the affected layout. Confirm a drag or resize screenshot shows a
pending proposal and cancel the gesture before checking persisted data.
Check the EventEditor draft across the desktop breakpoint and above a
simulated Android IME.

For Focus, preserve the local timer rebuild boundary and check active, paused,
break and interrupted review states through the existing entry points. Check
habit and goal editor action geometry with an Android keyboard inset. Reuse
repository and duration evidence when those owners are unchanged.

For Settings and Sync presentation, check the narrow section picker, long
account labels, last success, pending work and the conflict review entry point.
Android native widget geometry can use the 180 and 380 dp representative
matrix at 100% and 150% text. Track physical launcher and Windows shell
checks separately.

For SQLite, recurrence, and profile changes, include focused migration/round-trip or isolated in-memory/disposable-profile tests as appropriate. Preserve production data; never open or migrate the personal profile to test a change. For native IPC or widget rendering/input changes, build the native Release target, run `TodorbitWidget.exe --self-test`, then follow the relevant manual checks in `docs/windows-widget.md` on an isolated profile. For update/installer changes, use `docs/SOFTWARE_UPDATES.md` and `docs/ACCEPTANCE.md`; verify package identity, helper failure paths, and disposable upgrade behavior before release claims.

At integration or release checkpoints run `flutter analyze --no-pub`, relevant `flutter test` coverage (full serial suite when broad behavior changed), native and Windows Release builds, and packaged self-test as applicable. The exact build commands and profile setup are in `docs/DEVELOPMENT.md`. Run GUI checks in an isolated Windows profile when available, and distinguish live debug GUI, Release GUI, offscreen render, widget test, and manual native checks in the report. Record failures and unverified items explicitly; update `docs/PROGRESS.md` after meaningful work.
