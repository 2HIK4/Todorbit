# Todorbit UI Implementation Strategy

**Status:** Foundation planning â€” no production code changed
**Branch:** `design-foundation-docs`
**Date:** 2026-11-20

---

## 1. Development Baseline

- **Active working branch:** `codex/fix-phantom-sync-conflict` (HEAD `5803e52`)
- **Documentation branch:** `design-foundation-docs` (branched from `codex/fix-phantom-sync-conflict`)
- **Architecture branch:** `feature/todorbit-release-p8` â€” contains ARCH-02 through ARCH-09 improvements that must be integrated before the UI pilot
- **Analysis:** `flutter analyze --no-pub` passes clean on `design-foundation-docs`
- **No token refactor has been implemented in production code**

---

## 2. Architecture Prerequisites

Integrate these before starting Phase 2 (Pilot):

| ARCH | Commit | What it provides | Why needed |
|------|--------|-----------------|-----------|
| ARCH-02 | `9276a4e` | Platform resource dialog extraction | Removes cross-feature cycle; prevents dialog refactors from breaking platform adapters |
| ARCH-03 | `adf5525` | SyncStatusButton decoupled from settings | Prevents settings-import regression during panel refactor |
| ARCH-04 | `45f0e12` | Calendar-workspace boundary enforcement | Protects calendar from workspace UI changes |
| ARCH-07 | `6a25ad6` | Repository transaction encapsulation | Required before introducing `TaskPresentationService` |
| ARCH-08/09 | `dad29af` | Architecture docs + CI boundary tests | Preserves boundary rules during UI migration |

Do **not** merge in this documentation task. Raise a separate PR targeting the appropriate integration branch.

---

## 3. Reusable Existing Components

| Component | Location | Reuse in |
|-----------|---------|---------|
| `buildAppTheme()` | `lib/features/shared/app_theme.dart` | All new screens â€” do not duplicate theme logic |
| `AppSpacing` | `lib/features/shared/app_spacing.dart` | All padding/spacing â€” extend with `AppLayout` |
| `AppMotion` | `lib/features/shared/app_motion.dart` | All animated transitions |
| `TaskListGroupView` | `lib/features/shared/task_list_group.dart` | Recurring task grouping in `AppTaskRow` |
| `DisclosureTile` | `lib/features/shared/disclosure_tile.dart` | Advanced settings sections in task detail |
| `SettingsSection` | `lib/features/shared/settings_section.dart` | Grouped settings panels |
| `UnsavedEditorGuard` | `lib/features/shared/unsaved_editor_guard.dart` | Task editor close protection |
| `DialogActionBar` | `lib/features/shared/dialog_action_bar.dart` | Consistent dialog action buttons |

---

## 4. Proposed Design System Structure

```
lib/features/shared/
â”œâ”€â”€ app_spacing.dart          # AppSpacing + AppLayout (extend existing)
â”œâ”€â”€ app_theme.dart            # buildAppTheme() (existing â€” do not duplicate)
â”œâ”€â”€ app_theme_extension.dart  # TodorbitThemeTokens ThemeExtension (NEW)
â”œâ”€â”€ app_motion.dart           # AppMotion (existing)
â”œâ”€â”€ app_task_row.dart         # AppTaskRow shared widget (NEW)
â”œâ”€â”€ app_task_detail_panel.dart  # AppTaskDetailPanel with resize (NEW)
â”œâ”€â”€ app_modal_shell.dart      # AppModalShell responsive wrapper (NEW)
â”œâ”€â”€ disclosure_tile.dart      # (existing â€” reuse)
â”œâ”€â”€ task_list_group.dart      # (existing â€” reuse)
â””â”€â”€ ...
```

---

## 5. Centralized Design Tokens

### Extend `app_spacing.dart`

```dart
abstract final class AppLayout {
  static const double breakpointCompact = 600;
  static const double breakpointMedium  = 1050;  // replaces magic 1050
  static const double breakpointWide    = 1200;  // replaces magic 1200
  static const double pageInsetH        = 24;
  static const double pageInsetV        = 16;
  static const double panelMinWidth     = 320;
  static const double panelDefaultWidth = 380;
  static const double panelMaxWidth     = 560;
  static const double dialogMinWidth    = 320;
  static const double dialogMaxWidth    = 560;
  static const double minTapTarget      = 48;
}
```

### Typography (already in `app_theme.dart`)

Feature widgets must reference `Theme.of(context).textTheme.*` â€” not raw `TextStyle` instances.

### ThemeExtension for Developer Overrides

```dart
// lib/features/shared/app_theme_extension.dart
class TodorbitThemeTokens extends ThemeExtension<TodorbitThemeTokens> {
  const TodorbitThemeTokens({this.panelDefaultWidth, this.accentOverride});
  final double? panelDefaultWidth;
  final Color?  accentOverride;
  @override
  TodorbitThemeTokens copyWith({double? panelDefaultWidth, Color? accentOverride}) =>
      TodorbitThemeTokens(
        panelDefaultWidth: panelDefaultWidth ?? this.panelDefaultWidth,
        accentOverride:    accentOverride    ?? this.accentOverride,
      );
  @override
  TodorbitThemeTokens lerp(TodorbitThemeTokens? other, double t) => this;
}
```

Register in `buildAppTheme()` via `ThemeData.extensions`.

---

## 6. Shared Component Strategy

### AppTaskRow

- Takes a `LifeTask` domain model
- Priority: colored left border (4 dp) using `scheme.error` / `scheme.tertiary` / `scheme.primary`
- Recurrence: `Icon(Icons.repeat, size: 14)` badge overlaid on trailing area
- Dates: `scheme.error` for overdue, `scheme.onSurfaceVariant` otherwise
- Subtask progress: shown only when `childCount > 0` â€” use `TaskListGroupView` for expansion
- Uses `AppSpacing.gap` / `AppSpacing.content` / `AppLayout.minTapTarget`
- `Semantics(label: '${task.title}, ${priority}, due ${date}', button: true)`

### AppTaskDetailPanel (desktop)

- Stateful widget managing panel width via `ValueNotifier<double>`
- Left edge: `GestureDetector` with `onHorizontalDragUpdate` adjusting width within `AppLayout.panelMin/MaxWidth`
- Width persisted via `AppController` / profile JSON
- Primary section: title, project, dates, priority, description
- Collapsible sections (`DisclosureTile`): Recurrence, Reminders, Dependencies, Tags

### AppModalShell

- Desktop: `Dialog` with `ConstrainedBox(minWidth: AppLayout.dialogMinWidth, maxWidth: AppLayout.dialogMaxWidth)`
- Android: `showModalBottomSheet` with appropriate corner radius
- Uses `DialogActionBar` for action buttons

---

## 7. Separation of Presentation from Business Logic

**Current state:** Most feature widgets read `AppController` via Riverpod and call domain methods correctly. The key violations are:
- Some editors call `LifeRepository` methods directly (bypassing `AppController` command pattern)
- `SyncStatusButton` (addressed by ARCH-03) imported settings dialogs directly

**Rule for new code:**
```
Feature widget â†’ AppController (Riverpod watch/read) â†’ LifeRepository â†’ SQLite
                                                      â†’ Domain calculations
Feature widget â†’ Domain models (read-only view)
```

Do not introduce a new router, state manager, or service locator. Use existing Riverpod providers.

---

## 8. Customization and Extension Architecture

| Audience | Mechanism | Scope |
|---------|-----------|-------|
| End-user | Settings â†’ Appearance â†’ Customize Theme | Accent color, surface, background, text colors via `ThemePalette` JSON |
| Developer | `TodorbitThemeTokens` ThemeExtension | Panel sizing, secondary tokens; requires recompile |
| Contributor | Modify `buildAppTheme()` | Full theme control; subject to code review |

**No runtime YAML file reading.** The JSON theme system in `lib/data/appearance_preference_store.dart` is the installed-app customization path.

---

## 9. Smallest Safe Pilot

**Branch:** Create `feature/ui-design-system-pilot` from the merge result of `feature/todorbit-release-p8` into `codex/fix-phantom-sync-conflict` (after ARCH integration).

**Scope (3â€“5 day effort estimate):**

1. Add `AppLayout` class to `lib/features/shared/app_spacing.dart` (~30 lines)
2. Create `lib/features/shared/app_theme_extension.dart` with `TodorbitThemeTokens` (~40 lines)
3. Create `lib/features/shared/app_task_row.dart` (~120 lines)
4. Create `lib/features/shared/app_task_detail_panel.dart` (~150 lines)
5. In `lib/features/workspace/workspace.dart`:
   - Replace `1050` literals (lines 517, 546, 949) with `AppLayout.breakpointMedium`
   - Replace `1200` literals (line 1039) with `AppLayout.breakpointWide`
   - Replace inline task-row `TextStyle` literals with `theme.textTheme.*`
   - Wire the existing task list to `AppTaskRow`
   - Replace the detail panel with `AppTaskDetailPanel`

**Do not touch:** sync, backup, recurrence logic, database schema, mobile shell, calendar, Windows native widget.

---

## 10. Acceptance Criteria

### Level 1 (required, run immediately)
- `flutter analyze --no-pub` exits 0
- `flutter test test/widget_test.dart` (or any new task-row widget tests) pass
- Widget tests render `AppTaskRow` at 400, 800, 1300 dp with no overflow

### Level 2 (required, run immediately â€” these are critical boundaries)
- Existing repository tests pass: `flutter test test/repository_test.dart`
- Existing workspace tests pass: `flutter test test/workspace_test.dart`
- Existing theme tests pass: `flutter test test/theme_customization_test.dart`

### Manual QA (before Codex review)
- Side panel drag-to-resize works; preference persists across app restart
- Task rows show recurrence badge, priority indicator, overdue date in red
- Subtask expansion works via existing `TaskListGroupView`
- No overflow at 150% text scale (Windows accessibility scaling)
- Both light and dark themes render correctly

### Level 3 (deferred â€” record in DEFERRED_VERIFICATION.md)
- Cross-platform regression on Android
- Windows native widget behavior unchanged
- Full golden test suite

---

## 11. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| ARCH branch conflicts during integration | Medium | High | Integrate ARCH into the working branch first; run all tests before starting UI work |
| `AppTaskDetailPanel` resize breaks existing editor save guard | Low | Medium | Reuse `UnsavedEditorGuard`; write a targeted test for panel close with unsaved changes |
| Raw-literal replacement introduces regression | Low | Medium | Replace one file at a time; run Level 1 tests after each file |
| Android tap-target fix regresses mobile layout | Low | Low | Mobile is Phase 3; keep it out of the pilot scope |
| Golden test failures after AppTaskRow introduction | Medium | Low | Update baselines only after design direction is approved |

---

## 12. Files for Codex Review

| File | Change | Review focus |
|------|--------|-------------|
| `lib/features/shared/app_spacing.dart` | Add `AppLayout` class | Constant values match existing magic numbers exactly |
| `lib/features/shared/app_theme_extension.dart` | New `TodorbitThemeTokens` | ThemeExtension lifecycle correct; no breaking change to existing theme |
| `lib/features/shared/app_task_row.dart` | New shared widget | Domain model usage correct; Semantics accurate; tap target â‰¥ 48 dp |
| `lib/features/shared/app_task_detail_panel.dart` | New resizable panel | Resize persisted correctly; UnsavedEditorGuard wired; no DB access |
| `lib/features/workspace/workspace.dart` | Replace magic breakpoints + raw literals | No behavioral change; only style/constant substitution |

---

*This document guides the first implementation sprint. Update it after each phase completes.*
