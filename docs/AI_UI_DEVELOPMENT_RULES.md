# Todorbit AI Agent UI Development Rules

**Status:** Permanent development standard
**Applies to:** All future coding agents (Gemini, Claude, Codex, GPT) working on Todorbit UI
**Authored:** 2026-11-20
**References:**
- Canonical Design System: [`docs/UI_DESIGN_SYSTEM.md`](UI_DESIGN_SYSTEM.md)
- UI Quality Skill: [`.agents/skills/ultimate-ui-ux/SKILL.md`](../.agents/skills/ultimate-ui-ux/SKILL.md)
- Engineering Quality Skill: [`.agents/skills/todorbit-engineering-quality/SKILL.md`](../.agents/skills/todorbit-engineering-quality/SKILL.md)
- Workflow and Handoffs: [`docs/CODEX_WORKFLOW.md`](CODEX_WORKFLOW.md)

---

## 1. Follow the Centralized Design System

- **No raw spacing literals:** Never write `EdgeInsets.all(16)` or `SizedBox(height: 8)` with magic numbers. Use `AppSpacing.small`, `AppSpacing.gap`, `AppSpacing.related`, `AppSpacing.content`, `AppSpacing.section`, or `AppLayout.*` constants from `lib/features/shared/app_spacing.dart`.
- **No raw TextStyle literals:** Never write `TextStyle(fontSize: 14, fontWeight: FontWeight.bold)`. Use `Theme.of(context).textTheme.*` (defined in `buildAppTheme()` in `lib/features/shared/app_theme.dart`).
- **No magic breakpoint numbers:** Never write `if (width < 1050)` or `constraints.maxWidth >= 1200`. Use `AppLayout.breakpointCompact` (600), `AppLayout.breakpointMedium` (1050), or `AppLayout.breakpointWide` (1200).
- **Color tokens:** Always consume colors from `Theme.of(context).colorScheme` (`primary`, `surface`, `onSurface`, `onSurfaceVariant`, `error`, `outlineVariant`). Do not hardcode hex values like `Color(0xFF3B6FE0)` in feature code.

---

## 2. Reuse Existing Shared Components

Before writing any new UI widget, search `lib/features/shared/` to find existing components:

| Need | Component | File |
|------|-----------|------|
| Spacing & layout constants | `AppSpacing`, `AppLayout` | `lib/features/shared/app_spacing.dart` |
| Theme & typography | `buildAppTheme()` | `lib/features/shared/app_theme.dart` |
| Animated transitions | `AppMotion` | `lib/features/shared/app_motion.dart` |
| Collapsible disclosure | `DisclosureTile` | `lib/features/shared/disclosure_tile.dart` |
| Settings grouping | `SettingsSection` | `lib/features/shared/settings_section.dart` |
| Recurring task grouping | `TaskListGroupView` | `lib/features/shared/task_list_group.dart` |
| Unsaved editor protection | `UnsavedEditorGuard` | `lib/features/shared/unsaved_editor_guard.dart` |
| Dialog actions | `DialogActionBar` | `lib/features/shared/dialog_action_bar.dart` |
| Task row presentation | `AppTaskRow` | `lib/features/shared/app_task_row.dart` (Pilot) |
| Task detail side panel | `AppTaskDetailPanel` | `lib/features/shared/app_task_detail_panel.dart` (Pilot) |
| Modal dialogs | `AppModalShell` | `lib/features/shared/app_modal_shell.dart` (Phase 4) |

**Do not introduce parallel implementations of any component listed above.**

---

## 3. Respect Separation of Concerns

```
[Presentation: lib/features/]
         â†“ reads domain models, dispatches commands
[Application Coordination: AppController (Riverpod)]
         â†“ executes transactions
[Persistence: LifeRepository / Drift SQLite: lib/data/]
```

- **UI widgets must not touch `repository.db` directly.** Always go through `AppController` commands or `LifeRepository` public query APIs.
- **UI widgets must not call `MethodChannel` directly.** Native platform calls belong in `lib/platform/windows/` or `lib/platform/android/`.
- **Domain logic must remain pure.** `lib/domain/` must never import Flutter widgets or platform packages.

---

## 4. Test Responsive Layouts and UI States

Every new or modified screen must be verified across at least three distinct viewport widths:

1. **Compact (< 600 dp):** Android phone / narrow split window. No horizontal overflow.
2. **Medium (600â€“1050 dp):** Tablet / snapped desktop half-screen. Side-rail navigation; overlay or slide-over panel.
3. **Wide (â‰¥ 1200 dp):** Full desktop monitor. Two-pane layout with persistent, resizable side panel.

**Accessibility scaling test:** Set `textScaleFactor = 1.5` in a widget test and assert `find.byType(...)` renders without `A RenderFlex overflowed...` errors.

---

## 5. Review Rendered UI Where Practical

- When browser or live Flutter tools are available, inspect the actual rendered output.
- If live inspection is unavailable, state clearly in your report: **"Rendered UI not visually verified; verified via static analysis and widget test."** Never invent visual claims or assume layout correctness from a passing compile.
- Windows physical behavior (DPI scaling, native window snapping, native widget IPC) requires native testing; report automated passes as non-proof of physical Windows behavior.

---

## 6. Preserve Existing Functionality (Zero Regression Gate)

Never break or degrade:
- Task planned dates vs. deadlines (they are separate domain concepts; never merge them).
- Recurring task generation and advancement.
- Google Drive sync journals and backup snapshots.
- Compare-and-swap (CAS) task revision concurrency tokens.
- Windows native desktop companion widget communication.
- Focus sessions and time tracking records.
- User profile isolation (never test against production `%APPDATA%\TodoPilot`).

---

## 7. Documentation and Knowledge Preservation

- **Update README:** If a user-facing workflow, keybinding, or setting changes, update `README.md`.
- **Update Architecture docs:** If component boundaries or relationships change, update `docs/ARCHITECTURE_MAP.md` and `docs/ARCHITECTURE.md`.
- **Improve AI skills:** When a non-trivial debugging pattern, edge case, or architecture lesson is discovered, update the relevant local skill reference in `.agents/skills/`.
- **Record decisions:** Add major architectural choices to `docs/DECISIONS.md`.

---

## 8. Add Regression Tests and Prevention Rules

- Every bug fix must include a test that reproduces the defect and fails without the fix.
- For UI layout bugs: add a widget test rendering the component with the boundary data (e.g., long titles, 150% text scale, empty subtasks).
- Golden tests: never update baselines automatically. Golden baseline updates require explicit review and approval.

---

## 9. Report Exact Changes and Verification Evidence

Every completion report must provide:
1. **Branch and HEAD commit SHA.**
2. **Exact command executed.**
3. **Whether the command actually executed or was planned.**
4. **Exit status and relevant output snippet.**
5. **Exact commit / working tree state tested.**
6. **What the result actually proves** (e.g., "Proves static analysis clean; does not prove runtime behavior").
7. **Any pending deferred verification** (logged in `docs/DEFERRED_VERIFICATION.md`).
8. **An entry in `docs/AI_REVIEW_QUEUE.md`** for the Codex reviewer.

---

*Adherence to these rules is mandatory for all agents working on Todorbit.*
