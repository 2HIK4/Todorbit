# Todorbit Design System

**Document status:** Foundation specification â€” not yet implemented in production
**Branch authored on:** `design-foundation-docs`
**Baseline commit:** `5803e52e017d2a1a69d8d42e239296d61dd75588`
**Flutter analysis:** Passed (`flutter analyze --no-pub` â†’ "No issues found!", exit 0, 2026-11-20)
**Token refactor:** NOT yet implemented â€” this document specifies future work

> [!IMPORTANT]
> This document describes the *intended* design system. No production files have been modified.
> ARCH-02 through ARCH-09 are on `feature/todorbit-release-p8` only and must be integrated
> before the UI pilot begins.

---

## 1. Design Principles

1. **Excellent defaults.** A new user sees a clean, consistent, polished experience with zero configuration.
2. **Progressive Disclosure.** Primary actions (add task, complete, quick filter) are always visible. Advanced settings (recurrence patterns, reminders, batch operations) appear in collapsible sections revealed on demand.
3. **Reduced clutter.** Implementation details, internal status codes, and irrelevant technical explanations are hidden unless the user needs them for a decision.
4. **Deep customization.** End-users adjust themes via Settings â†’ Appearance. Developers override design tokens via `TodorbitThemeTokens` (a Flutter `ThemeExtension`). No runtime YAML reading is involved.
5. **Adaptive layout.** Windows uses persistent side-rail navigation + resizable task-details panel. Android uses bottom navigation + full-screen detail. Both share the same design language and components.
6. **Functional preservation.** No design change may break task scheduling, recurrence, sync, backups, encryption, alarms, or the native Windows widget.

---

## 2. Existing Design Infrastructure (Verified)

The following files already exist and provide partial token infrastructure:

| File | Purpose | Status |
|------|---------|--------|
| `lib/features/shared/app_spacing.dart` | `AppSpacing` class: `small=4`, `gap=8`, `related=12`, `content=16`, `section=24` dp | âœ… Exists |
| `lib/features/shared/app_theme.dart` | `buildAppTheme()`: Material 3 theme with custom palette, typography scale, button/card/dialog themes | âœ… Exists |
| `lib/features/shared/app_motion.dart` | `AppMotion`: 180 ms duration, respects `MediaQuery.disableAnimations` | âœ… Exists |
| `lib/features/shared/task_list_group.dart` | `TaskListGroupView`: recurring group expansion widget | âœ… Exists |
| `lib/features/shared/disclosure_tile.dart` | Collapsible tile for Progressive Disclosure | âœ… Exists |
| `lib/features/shared/settings_section.dart` | Settings group wrapper | âœ… Exists |

**Actual gaps confirmed in source:**
- Magic breakpoints (`1050`, `1200` px) in `workspace.dart` lines 517, 546, 949, 1039 â€” not referenced from `AppSpacing`.
- Raw `TextStyle(fontSize: 12, ...)` and `EdgeInsets.fromLTRB(...)` literals in `workspace.dart` lines 1140, 1161, 1182, 1205, 1244, 1304. The `app_theme.dart` typography scale exists but is not consistently referenced in feature widgets.
- No `AppTaskRow` shared component â€” task rows are built inline in both `workspace.dart` and `mobile_workspace.dart`.
- No `AppModalShell` responsive modal wrapper â€” dialogs use ad-hoc `SizedBox` sizing.

---

## 3. Design Tokens: Required Additions

### 3.1 Layout Tokens

Add to `lib/features/shared/app_spacing.dart` (extend `AppSpacing`):

```dart
abstract final class AppLayout {
  // Responsive breakpoints (replace magic numbers in workspace.dart)
  static const double breakpointCompact  = 600;   // narrow desktop / portrait tablet
  static const double breakpointMedium   = 1050;  // current narrow-desktop threshold
  static const double breakpointWide     = 1200;  // current wide-desktop threshold

  // Page insets
  static const double pageInsetH = 24;   // horizontal page padding
  static const double pageInsetV = 16;   // vertical page padding

  // Side panel
  static const double panelMinWidth  = 320;
  static const double panelDefaultWidth = 380;
  static const double panelMaxWidth  = 560;

  // Dialogs
  static const double dialogMinWidth = 320;
  static const double dialogMaxWidth = 560;

  // Touch / click targets
  static const double minTapTarget = 48;
}
```

### 3.2 Color Tokens

The existing `buildAppTheme()` already derives `ColorScheme` from `ThemePalette`. No new color file is needed. The following semantic roles are already available via `Theme.of(context).colorScheme`:

- `primary` / `onPrimary` â€” accent actions
- `surface` / `onSurface` â€” backgrounds and primary text
- `onSurfaceVariant` â€” secondary/metadata text
- `error` / `onError` â€” error states
- `outlineVariant` â€” borders and dividers

**Required:** A `ThemeExtension` (`TodorbitThemeTokens`) for per-token developer overrides without touching `buildAppTheme()`. This is new work.

### 3.3 Typography

The existing `buildAppTheme()` already defines the full typography scale:

| Role | Size | Weight | Use |
|------|------|--------|-----|
| `headlineMedium` | 28 sp | w600 | Screen titles |
| `headlineSmall` | 24 sp | w600 | Section titles |
| `titleLarge` | 22 sp | w600 | Dialog titles, AppBar |
| `titleMedium` | 18 sp | w600 | Panel headers |
| `titleSmall` | 15 sp | w600 | List group headers |
| `bodyLarge` | 16 sp | w400 | Primary body text |
| `bodyMedium` | 14/15 sp | w400 | Task titles, default text |
| `bodySmall` | 13 sp | w400 | Metadata, secondary labels |
| `labelSmall` | 12 sp | w400 | Badges, timestamps |

> [!WARNING]
> Raw `TextStyle` literals in feature widgets MUST be replaced with `Theme.of(context).textTheme.*`
> references. The scale is defined centrally but not yet consistently used.

### 3.4 Motion

`AppMotion.duration = 180ms` with `Curves.easeOutCubic`. Respects `MediaQuery.disableAnimations`. Use `AppMotion.style(context)` for all animated transitions.

---

## 4. Required Shared Components

### 4.1 `AppTaskRow` (new)

A shared widget replacing the inline task-row implementations in `workspace.dart` and `mobile_workspace.dart`.

**Contract:**
```dart
class AppTaskRow extends StatelessWidget {
  final LifeTask task;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onComplete;
  // Priority badge, recurrence indicator, date chips built internally
  // from task domain model â€” no raw TextStyle literals
}
```

**Requirements:**
- Uses `Theme.of(context).textTheme` for all text
- Uses `AppSpacing` for all padding
- Minimum tap target: `AppLayout.minTapTarget` (48 dp)
- Wraps interactive elements in `Semantics` with accurate labels
- Priority shown as a colored left-border or leading icon, not text
- Recurrence shown as a small `Icons.repeat` badge, not raw text
- Due date chip uses `scheme.error` when overdue

### 4.2 `AppModalShell` (new)

Responsive dialog wrapper replacing ad-hoc `SizedBox` constraints.

**Contract:**
```dart
class AppModalShell extends StatelessWidget {
  final String title;
  final Widget content;
  final List<Widget> actions;
  // Desktop: constrained dialog (dialogMinWidth..dialogMaxWidth)
  // Android: bottom sheet or full-screen modal
}
```

### 4.3 `AppTaskDetailPanel` (new, desktop only)

Resizable side panel for task details. Replaces the fixed-width task editor layout.

**Requirements:**
- Draggable resize handle on the left edge
- Width clipped to `AppLayout.panelMinWidth`..`AppLayout.panelMaxWidth`
- Preference persisted via `AppController` / profile JSON
- Primary fields visible immediately; advanced fields (recurrence, reminders, dependencies) in collapsible `DisclosureTile` sections

---

## 5. Progressive Disclosure Rules

| Context | Always visible | Behind disclosure |
|---------|---------------|-------------------|
| Task row | Title, checkbox, priority, due date, recurrence badge | Checklist progress, session status, blocked-by indicator |
| Task detail panel | Title, project, dates, priority, description | Recurrence settings, custom reminders, prerequisites, batch tags |
| Settings screen | Current value, main toggle | Advanced sub-options, developer overrides |
| Sidebar | View categories, search, quick-add | Archived views, import/export, widget config |

---

## 6. Accessibility Requirements

- **Touch targets:** All interactive widgets â‰¥ 48 dp (enforced by `AppLayout.minTapTarget`).
- **Semantics:** Every interactive widget has a `Semantics` node with an accurate `label`. Use `Semantics(label: '...', button: true, child: ...)` wrappers where Material does not provide them automatically.
- **Contrast:** `buildAppTheme()` uses `foregroundOn()` to select black/white foregrounds; custom palettes must be verified with a runtime contrast check (not assumed from design specs).
- **Text scaling:** No hard-coded pixel dimensions in `RenderBox` widgets. Use `LayoutBuilder` / `MediaQuery` for adaptive sizing.
- **Reduce motion:** All animations gated through `AppMotion.style(context)`.

---

## 7. Responsive Layout Standards

| Viewport width | Layout mode | Detail panel | Navigation |
|---------------|-------------|-------------|-----------|
| < 600 dp (Android / narrow) | Single-pane | Full-screen push | Bottom nav |
| 600â€“1050 dp (compact desktop) | Single-pane + overlay panel | Slide-over drawer | Side rail (icons only) |
| â‰¥ 1050 dp (medium desktop) | Two-pane | Persistent side panel | Side rail (icons + labels) |
| â‰¥ 1200 dp (wide desktop) | Two-pane + detail | Persistent + resizable | Side rail (icons + labels) |

Breakpoint constants must come from `AppLayout`; remove magic literals `1050` and `1200` from feature code.

---

## 8. Developer Customization Architecture

```dart
// Define in lib/features/shared/app_theme_extension.dart
class TodorbitThemeTokens extends ThemeExtension<TodorbitThemeTokens> {
  final Color? accentOverride;
  final double? panelDefaultWidth;
  // ...
  @override
  TodorbitThemeTokens copyWith({...}) { ... }
  @override
  TodorbitThemeTokens lerp(TodorbitThemeTokens? other, double t) { ... }
}
```

Registered in `buildAppTheme()` via `ThemeData.extensions`. Feature widgets read it via `Theme.of(context).extension<TodorbitThemeTokens>()`.

**This is a Dart/Flutter mechanism only** â€” no runtime YAML file reading. Developer customization requires recompiling the app or using the existing JSON theme system in Settings â†’ Appearance.

---

## 9. Regression-Prevention Rules

1. **Token rule:** New UI code must reference `AppSpacing`, `AppLayout`, or `Theme.of(context).textTheme` â€” not raw `EdgeInsets` or `TextStyle` literals.
2. **Component rule:** Before adding a new interactive widget, check `lib/features/shared/` for an existing component.
3. **Semantics rule:** Every new interactive widget must include a `Semantics` node. Code review must verify this.
4. **Responsive rule:** New screens must have widget tests at three breakpoints: 400, 800, and 1300 dp wide.
5. **Overflow rule:** `flutter test` must report zero layout overflow warnings for the modified screen.
6. **Analysis rule:** `flutter analyze --no-pub` must exit 0 after every change. (Currently verified clean on `design-foundation-docs` at commit `5803e52`.)
7. **Golden baseline rule:** Visual regressions are caught by existing golden tests. Update baselines only with explicit approval; never auto-update.

---

## 10. Migration Phases

| Phase | Scope | Key files | Gate |
|-------|-------|-----------|------|
| **P0 â€“ Prerequisites** | Integrate ARCH-02 â†’ 09 from `feature/todorbit-release-p8` | â€” | Merge-base verification; all existing tests pass |
| **P1 â€“ Token Infrastructure** | Add `AppLayout` to `app_spacing.dart`; add `TodorbitThemeTokens`; replace magic breakpoints in `workspace.dart` | `lib/features/shared/app_spacing.dart`, `lib/features/shared/app_theme_extension.dart`, `lib/features/workspace/workspace.dart` | `flutter analyze` clean; no layout change in widget tests |
| **P2 â€“ Pilot: Task List + Details** | Implement `AppTaskRow`; introduce `AppTaskDetailPanel` with resize; remove inline TextStyle literals from `workspace.dart` | `lib/features/shared/`, `lib/features/workspace/workspace.dart` | Widget tests at 3 breakpoints; Level 2 critical tests pass; manual QA at 150% text scale |
| **P3 â€“ Mobile Alignment** | Apply `AppTaskRow` in `mobile_workspace.dart`; fix 32 dp icon-button tap targets; fix destructive search navigation | `lib/features/mobile/mobile_workspace.dart` | Parity checklist; navigation regression test |
| **P4 â€“ Full Adoption** | Migrate remaining dialogs to `AppModalShell`; remove all raw style literals | All UI files | CI full pass; Codex review |

---

## 11. Outstanding Dependencies Before Pilot

| Dependency | Location | Required for |
|-----------|---------|-------------|
| ARCH-02: Platform resource dialog extraction | `feature/todorbit-release-p8` commit `9276a4e` | Removes cross-feature cycle; needed before modifying dialog presentation |
| ARCH-03: SyncStatusButton decoupling | `feature/todorbit-release-p8` commit `adf5525` | Prevents sync-settings cycle regressing during panel refactor |
| ARCH-04: Calendar-workspace boundary | `feature/todorbit-release-p8` commit `45f0e12` | Protects calendar from workspace UI changes |
| ARCH-07: Repository transaction encapsulation | `feature/todorbit-release-p8` commit `6a25ad6` | Needed before introducing `TaskPresentationService` |

ARCH-05, 06, 08, 09 are beneficial but not strictly blocking the pilot.

---

*This document is authoritative for future UI development. Update it when new reusable lessons are discovered.*
