---
name: todorbit-regression
description: Select and run risk-based Todorbit regression checks for Flutter UI, SQLite or recurrence logic, profile settings, native Windows widget IPC, updates, and installer packaging. Use when validating a code change or release checkpoint.
---

# Todorbit regression

Identify changed boundaries with `git diff` and a targeted `rg` search. Reuse nearby tests and the installed Dart/Flutter MCP analyzer, LSP, DTD, and runtime diagnostics when applicable. Run the smallest relevant test set while editing, then widen only for shared behavior or an unresolved failure. Do not claim a test covers a physical Windows interaction it did not perform.

For SQLite, recurrence, and profile changes, include focused migration/round-trip or isolated in-memory/disposable-profile tests as appropriate. Preserve production data; never open or migrate the personal profile to test a change. For native IPC or widget rendering/input changes, build the native Release target, run `TodorbitWidget.exe --self-test`, then follow the relevant manual checks in `docs/windows-widget.md` on an isolated profile. For update/installer changes, use `docs/SOFTWARE_UPDATES.md` and `docs/ACCEPTANCE.md`; verify package identity, helper failure paths, and disposable upgrade behavior before release claims.

At integration or release checkpoints run `flutter analyze --no-pub`, relevant `flutter test` coverage (full serial suite when broad behavior changed), native and Windows Release builds, and packaged self-test as applicable. The exact build commands and profile setup are in `docs/DEVELOPMENT.md`. Run GUI checks in an isolated Windows profile when available, and distinguish live debug GUI, Release GUI, offscreen render, widget test, and manual native checks in the report. Record failures and unverified items explicitly; update `docs/PROGRESS.md` after meaningful work.
