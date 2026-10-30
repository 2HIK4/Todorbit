# Codex workflow

Use a new chat for a distinct objective; continue the current chat while fixing or reviewing the same change. Start with the goal, affected screen or behavior, constraints, and observable acceptance criteria. Link a prior decision or progress entry only when it matters.

Use low reasoning for narrow, reversible edits and routine questions; medium for multi-file implementation or debugging; high for migrations, native interop, difficult regressions, and architectural tradeoffs. Raise effort when evidence warrants it. Keep the model choice and effort adjustable per task; do not sacrifice correctness to save tokens.

## Working sequence

1. Inspect `git status --short`, branch and recent commits. Preserve unrelated work; never stash, discard or commit it implicitly. If a clean baseline is required and changes exist, use an isolated worktree or resolve ownership first. Create a focused `feature/`, `fix/` or `maintenance/` branch from the intended base; do not silently pull/merge over ongoing work.
2. Define scope and observable acceptance. Use [Architecture map](ARCHITECTURE_MAP.md), then read only the relevant deeper reference. Read [Progress](PROGRESS.md) for task selection or interrupted work, not every historical report.
3. Search relevant directories with `rg`; exclude `build/`, `.dart_tool/`, generated Windows files and dependencies. Find existing callers, shared controls, stores and nearby tests before adding an implementation.
4. Make the smallest appropriate change. Keep long tasks in reviewable checkpoints; record current source, changed boundaries, completed checks and next action when interrupted. Reinspect the working tree on resume rather than repeating completed work or trusting stale receipts.
5. Run focused checks from [Testing](TESTING.md). Widen for shared behavior, data safety, integration or release risk. Diagnose failures before repeating a command. Distinguish automated, rendered and physical Windows evidence.
6. Review `git diff --stat`, the full affected diff and `git diff --check`; check data compatibility, duplicated logic and out-of-scope files. Update durable docs when behavior or architecture changes.
7. When committing is requested or part of the agreed task, stage explicit paths, inspect the staged diff and commit verified work with a meaningful message. Keep unrelated changes out. Do not publish releases without an explicit request; use [Release](RELEASE.md) for release-ready changes.
8. Report behavior changed, checks and limits, branch/commit and working-tree state. Record failures and manual acceptance still pending.

Record durable product decisions in `docs/DECISIONS.md` and meaningful checkpoints in `docs/PROGRESS.md`. Keep handoffs to the current state, changed files, verification, and next concrete action. For Windows design use [Microsoft Fluent guidance](https://learn.microsoft.com/en-us/windows/apps/design/) first; use `docs/THEMING.md` for Todorbit tokens. Apple Design is an optional independent UX review, not the Windows platform rulebook.

For a UI audit or visual change, invoke `$todorbit-ui-review`; for change validation or a release checkpoint, invoke `$todorbit-regression`. Their sources are in `.agents/skills/`. The official Dart/Flutter plugin supplies the analyzer and live tooling; no separate MCP configuration is needed here.

## Focused verification examples

`tools/dev/verify.ps1 -Mode Feature -Feature <name> -Plan` previews the commands
without running them. Groups are explicit in `tools/dev/features.json`, not
inferred from filenames. Add `-ChangedPaths` and `-Tests` for related boundaries
outside a group. Quick requires both explicitly; Full always runs all host tests.
Full platform acceptance adds builds/device work with `-Platform` as documented
in [Testing](TESTING.md). Default host checks do not claim device acceptance.

| Request | Read first / verification choice |
| --- | --- |
| Small UI adjustment | Feature index entry and nearest shared control; Quick with changed Dart files and the relevant layout test; inspect compact/large text. |
| New task field | Task model/repository/editor plus readers and portability; `tasks` + `database`; Full for schema/shared-model changes. |
| Calendar fix | Identify Flutter versus native Calendar first; `calendar`, adding scheduling/series tests if dates or recurrence change. |
| Android notification | Dart projections and native alarm/job adapter; `notifications` then actual disposable-device delivery/permission/reboot checks. |
| Google Drive change | Transport, codec or restore boundary in the map; `drive`; authorized cross-client OAuth remains a separate acceptance gate. |
| Android update | `android-updates`; release Python gates; `-Platform Android -Device emulator-N` for native verification; actual installer approval is separate. |
| Database migration | Schema/startup gate, repository and both native readers; `database` while editing, Full and cross-platform restore before finalizing. |
| Windows-only change | Relevant Windows group; `-Platform Windows` for Release/packaged self-test; manual native checklist when shell/input/painting changes. |
| Cross-platform behavior | Shared domain/repository and both presentation adapters; focused groups while editing, Full plus both relevant platform gates at completion. |

Keep searches small, for example `rg -n 'scheduleRestore' lib/data/cloud lib/data/backup_service.dart`.
Ordinary `rg` honors Git ignores; do not use `--no-ignore`/`--hidden` for ordinary
exploration. Scope source analysis to `lib test integration_test test_driver`
when ignored worktrees/SDKs exist. Do not print generated `*.g.dart`, full test
progress, entire large editors or historical reports unless needed. Helper logs
and per-step timing/source receipts stay under ignored `.buildlog/verify/`.
Read a failing log before rerunning; passing unchanged gates need no repetition.

On interruption, record revision, changed boundaries, completed gate/log paths,
pending process/device identity and the next concrete check in Progress. On
resume inspect status/diff, validate that evidence matches source, and continue.
Never clean caches or rebuild unchanged native components just to establish context.

## Repository cost audit (2026-10-30)

At the recovered baseline there were 132 handwritten Dart source files (40,525
lines), 95 host-test files (17,821 lines). The largest sources were the 2,017-line
repository library, 1,868-line workspace, 1,720-line task editor and 1,130-line
controller. These sizes alone did not justify splitting stable APIs. Repository
parts already separate data features; mobile reuses domain/controller/codec logic;
native integrations already sit behind platform adapters. No dependency-injection
framework, duplicate business layer or speculative source split was added.

Concrete friction was repeated path/test discovery, missing Android rows in the
test guide, unbounded terminal test output, PowerShell 5 treating redirected build
warnings as failure, local Windows plugin symlink permissions, repeated dependency
resolution and baseline formatter debt. The feature index/catalog, bounded-log
verification helper, native exit-code handling, optional generated plugin
junctions, `-NoPub` build flag and mechanical formatting address those problems.
Android CI uses focused host checks instead of repeating Windows CI's full host
suite. The independent Windows full gate remains required by signed candidates;
Android still builds APKs and runs actual emulator integration. Remote timing is
unmeasured until the owner pushes/runs the workflows.
Root instructions remain brief; this guide owns workflow, the map owns entry
points, Architecture owns boundaries, and Testing owns verification gates.

Observed timings are recorded with source/log context in the current Android
finalization report linked from Progress. Do not infer precise token savings or
controlled speedups from differently scoped runs. No clean build/cache deletion,
SDK move or Kotlin cache relocation is needed for routine edits. Use a clean CI
build for reproducibility and keep full CI authoritative before release.

## Reusable request

```text
Change/fix: <observable behavior and affected screen/component>.
Acceptance: <expected outcomes and important edge cases>.
Constraints: <compatibility, scope, data or design limits>.
Relevant context: <file, issue or decision if known>.
Implement using AGENTS.md and task-relevant docs. Run risk-based checks,
report limits, and <commit / leave changes for review>. Do not publish.
```

## Navigation check

These are routing examples, not implementation requests:

| Future task | First references and implementation | Verification / constraint |
| --- | --- | --- |
| Calendar desktop widget resizing | Architecture native row, [widget guide](windows-widget.md); `CalendarWidgetLayout.cs`, `CalendarWidget.cs`, `WidgetSettings.cs` in `experiments/widget-shell-probe/` | Testing widgets row; native self-test and isolated manual resize/DPI; preserve saved bounds and bounded date grid/expanding agenda. Flutter Calendar is a different surface. |
| New persisted Settings option | Architecture settings row, [Customization](CUSTOMIZATION.md); relevant `lib/features/settings/` page, `AppController`, neighboring `lib/data/` store or repository | Testing settings/persistence rows; round-trip and malformed/old data, widget test; explicitly choose shareable vs device-local and preserve defaults. |
| Windows pre-release publication | [Release](RELEASE.md), [Updates](SOFTWARE_UPDATES.md), latest publication receipt linked from Progress; `pubspec.yaml`, native project, `tools/`, `installer/`, Windows CI | Full exact-source gates, approved config, draft assets/hashes, updater/recovery and manual limits. Explicit publication request required. |
