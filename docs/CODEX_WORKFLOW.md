# Codex workflow

Use a new chat for a distinct objective; continue the current chat while fixing or reviewing the same change. Start with the goal, affected screen or behavior, constraints, and observable acceptance criteria. Link a prior decision or progress entry only when it matters.

Use low reasoning for narrow, reversible edits and routine questions; medium for multi-file implementation or debugging; high for migrations, native interop, difficult regressions, and architectural tradeoffs. Raise effort when evidence warrants it. Keep the model choice and effort adjustable per task; do not sacrifice correctness to save tokens.

## Working sequence

1. Inspect `git status --short`, branch and recent commits. Preserve unrelated work; never stash, discard or commit it implicitly. If a clean baseline is required and changes exist, use an isolated worktree or resolve ownership first. Create a focused `feature/`, `fix/` or `maintenance/` branch from the intended base; do not silently pull/merge over ongoing work.
2. Define scope and observable acceptance. Use the subsystem map in [Architecture](ARCHITECTURE.md), then read only the relevant deeper reference. Read [Progress](PROGRESS.md) for task selection or interrupted work, not every historical report.
3. Search relevant directories with `rg`; exclude `build/`, `.dart_tool/`, generated Windows files and dependencies. Find existing callers, shared controls, stores and nearby tests before adding an implementation.
4. Make the smallest appropriate change. Keep long tasks in reviewable checkpoints; record current source, changed boundaries, completed checks and next action when interrupted. Reinspect the working tree on resume rather than repeating completed work or trusting stale receipts.
5. Run focused checks from [Testing](TESTING.md). Widen for shared behavior, data safety, integration or release risk. Diagnose failures before repeating a command. Distinguish automated, rendered and physical Windows evidence.
6. Review `git diff --stat`, the full affected diff and `git diff --check`; check data compatibility, duplicated logic and out-of-scope files. Update durable docs when behavior or architecture changes.
7. When committing is requested or part of the agreed task, stage explicit paths, inspect the staged diff and commit verified work with a meaningful message. Keep unrelated changes out. Do not publish releases without an explicit request; use [Release](RELEASE.md) for release-ready changes.
8. Report behavior changed, checks and limits, branch/commit and working-tree state. Record failures and manual acceptance still pending.

Record durable product decisions in `docs/DECISIONS.md` and meaningful checkpoints in `docs/PROGRESS.md`. Keep handoffs to the current state, changed files, verification, and next concrete action. For Windows design use [Microsoft Fluent guidance](https://learn.microsoft.com/en-us/windows/apps/design/) first; use `docs/THEMING.md` for Todorbit tokens. Apple Design is an optional independent UX review, not the Windows platform rulebook.

For a UI audit or visual change, invoke `$todorbit-ui-review`; for change validation or a release checkpoint, invoke `$todorbit-regression`. Their sources are in `.agents/skills/`. The official Dart/Flutter plugin supplies the analyzer and live tooling; no separate MCP configuration is needed here.

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
