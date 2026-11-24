# Codex workflow

Use a new chat for a distinct objective; continue the current chat while fixing or reviewing the same change. Start with the goal, affected screen or behavior, constraints, and observable acceptance criteria. Link a prior decision or progress entry only when it matters.

Use low reasoning for narrow, reversible edits and routine questions; medium for multi-file implementation or debugging; high for migrations, native interop, difficult regressions, and architectural tradeoffs. Raise effort when evidence warrants it. Keep the model choice and effort adjustable per task; do not sacrifice correctness to save tokens.

## Working sequence

1. Inspect `git status --short`, branch and recent commits. Preserve unrelated work; never stash, discard or commit it implicitly. If a clean baseline is required and changes exist, use an isolated worktree or resolve ownership first. Create a focused `feature/`, `fix/` or `maintenance/` branch from the intended base; do not silently pull/merge over ongoing work.
2. Define scope and observable acceptance. Run `.\dev doctor` and `.\dev context <feature>` (or use [Architecture map](ARCHITECTURE_MAP.md)), then read only the relevant deeper reference. Read [Progress](PROGRESS.md) for task selection or interrupted work, not every historical report.
3. Search relevant directories with `rg` or `Select-String`; exclude `build/`, `.dart_tool/`, generated Windows files and dependencies. Find existing callers, shared controls, stores and nearby tests before adding an implementation.
4. Make the smallest appropriate change. Keep long tasks in reviewable checkpoints (`.\dev handoff`); record current source, changed boundaries, completed checks and next action when interrupted. Reinspect the working tree on resume rather than repeating completed work or trusting stale receipts.
5. Before every test, consult [the persistent ledger](TEST_RUN_LEDGER.md), identify the changed behavior and smallest covering assertion, and compare source, assertions, dependencies, configuration and environment with prior passes. Prefer `.\dev impact` and `.\dev verify changed` (which enforces conservative impact selection and content-addressed evidence reuse; use `-Shadow` periodically to audit omitted suites). Whenever adding, renaming, or removing tests or feature files, update `tools/dev/features.json` and run `.\dev registry --refresh` + `.\dev registry --validate`. Record justified reuse/skips as well as executions with local time/offset and a dirty-source fingerprint. Never rerun solely because a new task started, after an unrelated edit, or for redundant confirmation. Before executing checks, review applicable receipts/CI and apply the [testing evidence policy and ledger](TESTING.md#choose-checks-by-changed-boundary). Select Quick, Feature, Critical or Release risk, reuse valid passes, and state what invalidates a rerun. Record each invocation's purpose/coverage, source/artifact, result and new/rerun reason in the task receipt; detailed logs stay ignored. Widen for shared behavior, data safety, integration or release risk. Diagnose failures before repeating a command (`.\dev diagnose last`). Distinguish automated, offscreen rendered, test-harness, live debug driver, and physical Windows evidence.
6. Review `git diff --stat`, the full affected diff and `git diff --check`; check data compatibility, duplicated logic and out-of-scope files. Update durable docs when behavior or architecture changes.
7. When committing is requested or part of the agreed task, stage explicit paths, inspect the staged diff and commit verified work with a meaningful message. Keep unrelated changes out. Do not publish releases without an explicit request; use [Release](RELEASE.md) for release-ready changes.
8. Report behavior changed, checks and limits, branch/commit and working-tree state. Record failures and manual acceptance still pending.

Record durable product decisions in `docs/DECISIONS.md` and meaningful checkpoints in `docs/PROGRESS.md`. Keep handoffs to the current state, changed files, verification, and next concrete action. For Windows design use [Microsoft Fluent guidance](https://learn.microsoft.com/en-us/windows/apps/design/) first; use `docs/THEMING.md` for Todorbit tokens.

For change validation or a release checkpoint, invoke `$todorbit-regression` from `.agents/skills/`. The official Dart/Flutter plugin supplies the analyzer and live tooling; no separate MCP configuration is needed here.

## Staged verification and AI responsibilities

Todorbit organizes verification into four distinct tiers to maximize developer speed while strictly protecting data integrity and formal release gates:

| Level | Scope | Timing | Enforcement |
|---|---|---|---|
| **Level 1: Fast** | Focused unit/widget tests for modified components, formatting checks, and relevant static analysis (`flutter analyze --no-pub <paths>`). | Immediately after editing relevant files. | Mandatory during coding; fast feedback. |
| **Level 2: Critical** | SQLite persistence, schema migrations, compare-and-swap (CAS) tokens, sync journals and apply logic, encryption codecs, backup/restore, recurrence calculations, alarms, and undo/redo stacks. | Immediately whenever affected functionality changes. | **Non-negotiable; never deferred** to save time. Unverified critical code must not be marked complete. |
| **Level 3: Deferred Regression** | Broad serial Flutter test suites, multi-module integration, cross-platform host regression, and release tooling unit tests. | Batched periodically or run on-demand. | Recorded in [Deferred verification](DEFERRED_VERIFICATION.md); triggered via GitHub Actions or checkpoints. |
| **Level 4: Release Acceptance** | Packaging (Release C++ build, Inno Setup installer, signed APK), isolated Windows Sandbox upgrades, physical display DPI checks, Android 16 KiB runtime, and real Google OAuth. | Prior to release candidates and publishing. | Recorded in [Deferred verification](DEFERRED_VERIFICATION.md); mandatory before publication. |

Level 2 applies to the affected invariant and callers, not every critical test in
the repository. Levels are selection policy, not four complete suites to run in
order. An unrelated UI/docs change needs only its relevant checks. Match source,
assertions, dependencies/configuration and environment before reusing evidence.

### Gemini's responsibilities
1. **Read instructions**: Read task-relevant Markdown guidance and project invariants before modifying code.
2. **Discover and apply skills**: Activate domain skills (`todorbit-engineering-quality`, `todorbit-regression`, `ultimate-ui-ux`) appropriately.
3. **Identify modified modules**: Scope changed files and map dependencies using `tools/dev/features.json` and [Architecture map](ARCHITECTURE_MAP.md).
4. **Run Level 1 tests**: Execute fast focused tests on modified files.
5. **Run Level 2 critical tests**: Execute the smallest tests covering affected critical invariants immediately; reuse matching valid evidence. A layout-only edit does not trigger unrelated migration/sync suites.
6. **Fix failures**: Resolve any failures at the root cause before completing the task.
7. **Record deferred verification**: Log any unexecuted Level 3 regression or Level 4 acceptance requirements in [Deferred verification](DEFERRED_VERIFICATION.md).
8. **Update review queue**: Record the unreviewed change entry in [AI Review Queue](AI_REVIEW_QUEUE.md) with `PENDING_CODEX_REVIEW`.
9. **Record evidence**: Document exact commands, timestamps, git SHA, and dirty-source fingerprints in task receipts and [Test run ledger](TEST_RUN_LEDGER.md).
10. **Never claim approval**: Never declare Codex approval or mark releases ready.

### Codex's responsibilities
1. **Inspect changes**: Inspect the full diff, status, and modified boundaries independently.
2. **Read queue**: Read pending entries in [AI Review Queue](AI_REVIEW_QUEUE.md).
3. **Review independently**: Challenge assertions, verify domain invariants, and ensure zero data loss.
4. **Fix confirmed defects**: Repair defects directly where invariants were broken.
5. **Reuse valid evidence**: Compare Git blob SHAs and dependency trees to reuse valid prior passes without rerunning unchanged suites.
6. **Run targeted checks**: Execute risk-justified tests on repaired boundaries.
7. **Audit deferred items**: Review pending items in [Deferred verification](DEFERRED_VERIFICATION.md) relevant to the change.
8. **Archive approved reviews**: Move completed review records from the queue to [AI Review History](AI_REVIEW_HISTORY.md).
9. **Preserve incomplete verification**: Retain unfinished acceptance gates in [Deferred verification](DEFERRED_VERIFICATION.md).
10. **Avoid redundant executions**: Do not rerun broad, unchanged full test suites merely to refresh a receipt.

### Separation of review queue and verification backlog
- [AI Review Queue](AI_REVIEW_QUEUE.md) tracks **unreviewed code changes**.
- [Deferred verification](DEFERRED_VERIFICATION.md) tracks **unfinished tests, regressions, and manual acceptance gates**.
- An approved review item means code logic is sound; it does **not** equal release readiness until all associated Level 4 gates in `DEFERRED_VERIFICATION.md` pass.

### Resource efficiency on 16GB host
- The primary development machine has 16GB RAM. Run all test commands sequentially with `--concurrency=1`.
- Never launch concurrent Flutter test processes, Gradle builds, or Android emulators simultaneously.
- Avoid repetitive full-suite executions; use focused tests during active development.

## Engineering quality workflow

[AGENTS.md](../AGENTS.md#skills-and-documentation-routing) requires
[Todorbit Engineering Quality](../.agents/skills/todorbit-engineering-quality/SKILL.md)
for any backend, domain, data persistence, SQLite migration, sync, encryption,
native Windows/.NET, Android/Kotlin, background alarms, or performance work.

1. **Selective Activation**: Do not load all references into context. Load only the reference
   document matching the current subsystem:
   - Data, SQLite, sync, alarms: `data-safety-and-persistence.md`
   - Platform interop, Windows .NET, Android Kotlin, calendar divergence: `cross-platform-architecture.md`
   - Profiling, CPU/memory, 16GB host limits: `performance-and-profiling.md`
   - Agent efficiency, search bounds, Git checkpoints: `agent-workflow-efficiency.md`
2. **Root-Cause Invariant**: Diagnose the entire caller graph and underlying causality before editing.
   Never apply band-aid display checks or silence exceptions to bypass invariant violations.
3. **Dual-Platform Boundary Verification**: Verify whether a feature targets Desktop (`Workspace` ->
   `CalendarView`), Android Mobile (`MobileWorkspace` -> `MobileCalendar`), or both. Never assume
   desktop widget updates propagate to Android mobile users.
4. **Data Safety**: Never wipe, drop, or reset SQLite databases, profiles, or user backups as an error fallback.
   All task edits MUST use SQL compare-and-swap (CAS) with advancing `updated_at` revision tokens.
5. **Context & Hardware Efficiency**: Machine has 16GB RAM. Run commands sequentially with `--concurrency=1`.
   Do not run parallel Flutter tests, Android emulators, or compiler jobs.

## UI quality workflow

[AGENTS.md](../AGENTS.md#skills-and-documentation-routing) requires
[Ultimate UI/UX](../.agents/skills/ultimate-ui-ux/SKILL.md) for any UI/UX impact,
including refactoring, optimization and indirect state/service changes. Work
without a user-experience impact does not trigger a UI audit.
It replaces the project-local UI review skill as the primary design workflow.
Do not routinely load global design skills alongside it. The repository maintains
the skill locally; keep changes scoped to a requested skill upgrade or a confirmed
compatibility/correctness fix, with metadata/reference validation. Its routing
loads only relevant sections for small changes. Full audits use the skill's
reachable-surface inventory and coverage ledger, including separate untested and
tooling/environment-blocked rows. See [integration and upgrade evidence](UI_SKILL_INTEGRATION.md).

1. Read the canonical skill once per session (reload if changed/context missing)
   and task-relevant references. Choose Build, Audit, Fix,
   Polish or Ship review; scope the inventory, issue-catalog checks, test matrix
   and report to the affected platforms, surfaces, states, journeys and adjacent
   shared consumers. Use the skill's seven-dimensional model; full audits assess
   all 67 category rows for applicability, while small changes load relevant rows.
   A small change does not require an application-wide audit.
2. Inspect the existing implementation and shared controls in `lib/features/shared/`.
   Use [Design](DESIGN.md), [Theming](THEMING.md) and relevant feature guidance.
   Identify requirements or confirmed causes before choosing a minimal solution.
   Preserve Todorbit's compact Fluent-inspired Windows identity, lavender default,
   semantic tokens, reusable components and working interactions. Functionality,
   drafts, preferences and data safety take precedence over appearance.
   Perform both implementation and experience inspections, including the skill's
   UX Necessity Review. Simplicity, understandable copy and fewer unnecessary
   decisions are acceptance criteria alongside functional correctness.
3. Identify shared Windows/Android components and affected platform-specific
   adapters. Respect Windows keyboard/mouse/focus and Android touch/Back/IME
   conventions; consult [Android parity](ANDROID.md) and the
   [native widget checklist](windows-widget.md) when applicable. Check supported
   sizes, desktop resizing/scaling, typography/text scaling, wrapping/clipping,
   spacing/alignment, contrast and accessibility as relevant. Maintain light/dark
   and custom palettes, including corresponding native widget tokens. Avoid
   unnecessary visual complexity; match the current design unless a deliberate
   design-system change is justified.
4. Implement with minimal unrelated changes. Follow [Testing](TESTING.md): reuse
   valid receipts, run relevant formatting/analysis and targeted geometry,
   behavior/semantics tests at ordinary/narrow sizes and larger text; include
   theme variants when affected. Inspect the running interface when tools are
   available, first verifying isolated child-process `APPDATA`, `LOCALAPPDATA`
   and resolved profile. Check interactions, edge states and platform behavior;
   fix confirmed regressions and recheck the failing case and affected consumers.
5. Record commands/actions, source, scope, results and rerun reasons. Distinguish
   widget tests/offscreen images, actual runtime inspection and physical platform
   evidence. Never claim visual verification without runtime inspection, or a
   100% error-free interface. Native painting/shell/input/DPI/menu changes still
   require Release/self-test and relevant manual checks. Report unverified cases.

### Future UI change quality gates

Before completing any UI or reliability change, verify the 16 quality gates from [Flutter Engineering](../.agents/skills/ultimate-ui-ux/references/flutter-engineering.md#explicit-ui--reliability-quality-gates) and sample the [Visual Audit Matrix](../.agents/skills/ultimate-ui-ux/references/test-matrix.md#8-todorbit-reusable-visual-audit-matrix):

1. **Keyboard-inset & viewport awareness**: Dialogs/sheets must wrap in scrollable containers with `viewInsets.bottom` clearance to avoid `RenderFlex` overflow when Android IME opens.
2. **Responsive breakpoints & text scaling**: Validated across 1.0× to 2.0× text scaling and narrow/wide breakpoints (320-1200dp) with wrapping metadata.
3. **Focus/hover/window-focus cancellation**: Mouse hover and tooltips clear on pointer exit or OS window blur; unregister gesture receivers on unmount.
4. **Identical card geometry across item variants**: Uniform margins, padding, minimum heights, and checkbox alignment regardless of optional tags or subtask counts.
5. **Parent-child continuity**: Navigating into subtasks or detail views preserves parent list scroll position and active selection on return.
6. **Recurrence grouping & identity**: Explicit visual and model separation of recurrence series vs individual occurrence overrides.
7. **No duplicated task routes**: Prevent multiple concurrent routes or editors for the same task.
8. **Idempotent timers**: Timers derived monotonically from UTC timestamps; multiple starts never spawn parallel ticking loops; clean cancellation in `dispose()`.
9. **Controlled scroll position**: Preserve scroll offsets across filters and background refresh using stable `PageStorageKey` or persistent offsets.
10. **State-preserving asynchronous navigation**: Check `mounted` before state/navigation calls; protect unsaved drafts if navigation occurs during async I/O.
11. **Destructive-action clarity**: Explicit modal confirmation with consequence copy, red destructive accent, and safe <kbd>Esc</kbd>/Cancel default.
12. **Animation restraint & reduced motion**: Respect `MediaQuery.disableAnimationsOf(context)`; keep transitions under 250ms with zero gratuitous bounce.
13. **Android content URI permissions**: Obtain persistable URI permissions across reboot, or copy picked files into managed app storage.
14. **Load-time evidence**: Ground any responsiveness claims in measured profiler/timeline evidence.
15. **Accessible text, contrast & keyboard**: WCAG AA contrast (>=4.5:1 / >=3:1), semantics labels on icon-only buttons, and complete keyboard traversal.
16. **Targeted widget & integration tests**: Focused widget tests covering layout under text scale and constraints; do not ship untested UI logic.

Active multi-stage UI and reliability tasks are tracked in [Todorbit UI & Reliability Program](TODORBIT_UI_RELIABILITY_PROGRAM.md).

Codex discovers the repo-local `SKILL.md` and matches its description; the root
instruction makes reading it mandatory even for small UI tasks. Manual invocation
is `$ultimate-ui-ux`. In a fresh session rooted in this repository, check the
skill selector (`$` or `/skills` in CLI/IDE) and ask Codex to read the skill for a
read-only review of an existing component. Confirm it loads this repository's
path. Codex detects skill changes automatically; restart Codex if the skill does
not appear. See [official skill discovery guidance](https://learn.chatgpt.com/docs/build-skills).

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
