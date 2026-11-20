# Todorbit UI Foundation â€” Handoff Documentation

**Branch:** `design-foundation-docs`
**Baseline commit:** `5803e52e017d2a1a69d8d42e239296d61dd75588`
**Authored:** 2026-11-20

> [!IMPORTANT]
> **Corrections to previous agent reports:**
> - `flutter analyze --no-pub` did run and passed (exit 0, "No issues found", 335 s), confirmed by background task `task-131`.
> - `tools/dev/verify.ps1 -Plan` **does NOT execute tests** â€” it generates a plan only, and exited with error code 1 on this branch. No test suite results exist for this branch.
> - The "token refactor" is **proposed future work**, not implemented. No production source was modified.
> - `docs/UI_AUDIT_FULL.md` **does not exist** in the repository. The UI audit findings were delivered as agent session messages; they are summarised below.
> - `docs/ARCHITECTURE.md` and `AGENTS.md` were **not modified** by this design task.
> - `feature/todorbit-release-p8` contains ARCH-02 through ARCH-09 (confirmed by `git log --oneline feature/todorbit-release-p8 --grep="ARCH"`). These are **not merged** into `design-foundation-docs`.

---

## 1. Verified UI/UX Findings

Findings are sourced from repository source inspection. File references were verified to exist.

| Severity | Symptom | Evidence (file:line) | Root-cause |
|----------|---------|----------------------|------------|
| **High** | Duplicate task-row implementations in desktop and mobile shells | `workspace.dart:2470+`, `mobile_workspace.dart:963â€“1002` | RC-1: Separate shells, shared logic not extracted |
| **High** | Hard-coded dialog dimensions, no responsive modal abstraction | `theme_dialog.dart:198â€“199`, `hotkeys_dialog.dart:104â€“105`, `goal_dialogs.dart:146â€“147` | RC-2: No `AppModalShell` |
| **High** | Accessibility gaps: 31 `Semantics` widgets total; mobile icon-buttons at 32 dp | `mobile_workspace.dart:488,502` | RC-3: No systematic accessibility wrappers |
| **High** | Destructive mobile search resets view context | `mobile_workspace.dart:551â€“558` | RC-4: Search coupled to navigation |
| **Medium** | Magic breakpoints (1050, 1200 px) and raw style literals | `workspace.dart:517,546,949,1039,1140,1161,1304` | RC-5: `AppSpacing` exists but not consistently used |
| **Medium** | Fragmented settings navigation; `SyncStatusButton` imports settings dialogs directly | `settings_hub_dialog.dart`, `sync_status_button.dart` | RC-6: No navigation abstraction |

---

## 2. Existing Design Infrastructure

The following shared files already exist and **must be reused**:

| File | Provides |
|------|---------|
| `lib/features/shared/app_spacing.dart` | `AppSpacing`: 5 spacing constants, scroll-padding helper |
| `lib/features/shared/app_theme.dart` | `buildAppTheme()`: full Material 3 theme, typography scale, button/card/dialog styles |
| `lib/features/shared/app_motion.dart` | `AppMotion`: 180 ms standard duration, `MediaQuery.disableAnimations` gate |
| `lib/features/shared/task_list_group.dart` | `TaskListGroupView`: recurring task group expansion |
| `lib/features/shared/disclosure_tile.dart` | Collapsible tile for Progressive Disclosure |

**Do not create parallel implementations of the above.**

---

## 3. Design System Requirements

See **[`docs/UI_DESIGN_SYSTEM.md`](UI_DESIGN_SYSTEM.md)** for the full specification.

Summary:
- Extend `AppSpacing` with an `AppLayout` class containing breakpoint constants (`600`, `1050`, `1200` dp) and panel sizing (`panelMinWidth=320`, `panelDefaultWidth=380`).
- Add `TodorbitThemeTokens` as a `ThemeExtension` for developer-level token overrides. This is a Dart/Flutter mechanism only, not runtime YAML.
- Typography: the scale in `app_theme.dart` is correct. Feature widgets must reference `Theme.of(context).textTheme.*` instead of raw `TextStyle` literals.
- Motion: `AppMotion.style(context)` is already defined. Use it.

---

## 4. Progressive Disclosure

- **Always visible:** task title, checkbox, priority, due date, recurrence badge, primary actions.
- **Behind disclosure:** recurrence settings, custom reminders, prerequisites, batch tags, checklist progress.
- Use existing `DisclosureTile` from `lib/features/shared/disclosure_tile.dart`.
- Sidebar width and task-details panel width are user-adjustable; persist preference via profile JSON.

---

## 5. Accessibility & Responsive Layout

- All interactive widgets â‰¥ 48 dp tap target (`AppLayout.minTapTarget`).
- Every new interactive widget requires a `Semantics` node with an accurate `label`.
- Contrast: `buildAppTheme()` already uses `foregroundOn()` for black/white selection. Custom palettes require runtime validation, not doc-level claims.
- No hard-coded pixel dimensions. Use `LayoutBuilder` / `MediaQuery`.

Responsive breakpoints:

| Width | Mode |
|-------|------|
| < 600 dp | Single-pane (Android) |
| 600â€“1050 dp | Compact desktop |
| â‰¥ 1050 dp | Two-pane desktop |
| â‰¥ 1200 dp | Wide two-pane + resizable detail |

---

## 6. Separation of Concerns

- UI widgets (`lib/features/`) read domain models and call `AppController` for commands.
- Direct `repository.db` access from UI is prohibited in new code.
- Native `MethodChannel` calls stay in platform adapter files, not in feature widgets.
- ARCH-02 through ARCH-09 on `feature/todorbit-release-p8` enforce these boundaries; integrate them before the pilot.

---

## 7. Customization Model

| User type | Mechanism |
|-----------|-----------|
| End-user | Settings â†’ Appearance â†’ Customize Theme (existing JSON palette system) |
| Developer | `TodorbitThemeTokens` ThemeExtension (new, requires rebuild) |

No YAML file is read at runtime by installed app builds. The existing JSON theme importer is the user-facing customization path.

---

## 8. Regression-Prevention Rules

1. New UI code: reference `AppSpacing`/`AppLayout`/`Theme.of(context).textTheme` â€” no raw literals.
2. Before adding a widget: search `lib/features/shared/` for existing equivalent.
3. Every interactive widget: requires a `Semantics` node. Verified in code review.
4. New screens: widget tests at 400, 800, 1300 dp.
5. `flutter analyze --no-pub` must exit 0 after every change.
6. Golden baselines updated only with explicit approval.

---

## 9. Incremental Migration

| Phase | Scope | Gate |
|-------|-------|------|
| P0 | Integrate ARCH-02 â†’ 09 from `feature/todorbit-release-p8` | All existing tests pass |
| P1 | Add `AppLayout` tokens; replace magic breakpoints | Analyze clean; no layout regression |
| P2 (Pilot) | `AppTaskRow`, `AppTaskDetailPanel` with resize, remove raw literals in `workspace.dart` | 3-breakpoint widget tests; Level 2 critical tests; manual QA at 150% text scale |
| P3 | `AppTaskRow` in mobile shell; fix 32 dp tap targets; fix search navigation | Parity checklist; navigation regression test |
| P4 | `AppModalShell` for all dialogs; full token adoption | CI full pass; Codex review |

---

## 10. First Implementation Pilot

**Target:** Desktop Task List + Task Details Panel
**Files:** `lib/features/workspace/workspace.dart`, `lib/features/shared/` (new components)

**Changes:**
1. Add `AppLayout` class to `lib/features/shared/app_spacing.dart`.
2. Create `lib/features/shared/app_task_row.dart` (`AppTaskRow` widget).
3. Create `lib/features/shared/app_task_detail_panel.dart` (`AppTaskDetailPanel` with resize handle).
4. Replace magic breakpoints in `workspace.dart` with `AppLayout.breakpointMedium` / `AppLayout.breakpointWide`.
5. Remove raw `TextStyle` / `EdgeInsets` literals from task-row-building code in `workspace.dart`; use theme + `AppSpacing`.

**Required before pilot:** P0 integration of ARCH-02, 03, 04, 07.

**Acceptance criteria:**
- `flutter analyze --no-pub` exits 0.
- Widget tests render `AppTaskRow` correctly at 400, 800, 1300 dp width with no overflow.
- Level 2 critical tests (repository transactions, sync) pass unchanged.
- Manual QA: side panel is resizable; no overflow at 150% text scale; recurrence and subtask indicators visible.

---

## 11. Visual Design Concepts

Two design directions were created as interactive HTML prototypes.
See: `docs/design-concepts/concept-a-refined-minimalist.html` and `docs/design-concepts/concept-b-modern-workspace.html`

Design recommendation: **Concept A (Refined Minimalist)** â€” see `docs/UI_IMPLEMENTATION_STRATEGY.md` for rationale.
**This recommendation is not approved.** Product owner review required before implementation begins.

---

## 12. Verification Evidence

| Check | Command | Result | Notes |
|-------|---------|--------|-------|
| Static analysis | `flutter analyze --no-pub` | âœ… Exit 0, no issues | On `design-foundation-docs`, commit `5803e52`, 2026-11-20 |
| Verify script `-Plan` | `tools/dev/verify.ps1 -Plan` | âŒ Exit 1, error "Quick requires explicit -ChangedPaths and -Tests" | Does NOT run tests; generates a plan. No test results exist for this branch. |
| ARCH commits | `git log --oneline feature/todorbit-release-p8 --grep="ARCH"` | âœ… ARCH-02 through ARCH-09 found | Present on `feature/todorbit-release-p8` only |

---

*Handoff prepared for Codex independent review. All stated evidence is from actual command output or repository inspection.*
