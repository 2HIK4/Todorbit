# Architectural Recommendation: Desktop vs Mobile Calendar Divergence

**Author**: Senior Software Architect & Engineering Team  
**Date**: 2026-11-11  
**Status**: Recommendation / Architectural Decision Record  
**Target Subsystems**: `lib/features/calendar/`, `lib/features/mobile/mobile_calendar.dart`, `lib/main.dart`

---

## 1. Executive Summary & Context

During the Beta 16 baseline audit, an essential architectural separation was identified:
- The desktop shell ([`lib/features/workspace/workspace.dart:1456`](file:///d:/AI_Projects/life_manager/lib/features/workspace/workspace.dart#L1456)) mounts `CalendarView`, hosting the redesigned interactive timeline canvas (Day/Week/Month views with 15-minute snapping, collision lanes, edge resizing, cross-day drag, and zoom transitions).
- The Android shell ([`lib/main.dart:918`](file:///d:/AI_Projects/life_manager/lib/main.dart#L918) -> [`lib/features/mobile/mobile_workspace.dart:401`](file:///d:/AI_Projects/life_manager/lib/features/mobile/mobile_workspace.dart#L401)) unconditionally mounts `MobileCalendar`, a separate touch-oriented agenda with a 54px cell day grid and vertical card lists.

**Key Finding**: Desktop interactive calendar features introduced in Beta 15 and refined in Beta 16 are **NOT exposed to production Android users**. Mobile touch enhancements in `CalendarMonthView` (e.g. `LongPressDraggable` on mobile platforms from commit `e70c7f4`) currently execute only in widget test environments or when desktop viewports inject mobile theme tokens.

---

## 2. Separate UI Responsibilities

The current divergence is not necessarily a bug; it reflects fundamentally different interaction paradigms:

| Dimension | Desktop (`CalendarView`) | Android Mobile (`MobileCalendar`) |
|---|---|---|
| **Primary Input** | Mouse cursor, mouse wheel, physical keyboard | Capacitive touch, multi-touch pinch, system Back |
| **Viewport Width** | Typical 1024px – 3840px (desktop monitor) | Typical 360px – 430px (portrait phone) |
| **Grid Presentation** | 24-hour vertical timeline grid with side-by-side collision lanes | Fading list agenda below compact month/week date picker |
| **Gestures** | Top/bottom edge resizing, 48px auto-scroll, Ctrl+wheel zoom | Vertical finger fling scrolling, tap to open full-screen editor |
| **History Navigation** | <kbd>Ctrl</kbd>+<kbd>Z</kbd> / <kbd>Ctrl</kbd>+<kbd>Y</kbd>, reactive toolbar pill | System Back button, SnackBar undo |

---

## 3. Risks of Premature Unification

Attempting to force `CalendarView` directly onto Android mobile devices presents severe operational and UX risks:
1. **RenderFlex Horizontal Overflows**: A 7-day Week view on a 390px mobile viewport yields ~44px per column. Even with ultra-compact cards, event titles, time chips, and resize handles become unreadable or cause horizontal layout overflow.
2. **Gesture Ambiguity**: Center-card dragging conflicts with vertical list flinging. While `LongPressDraggable` mitigates pickup conflict, drag-to-scroll within a crowded mobile timeline creates frustrating accidental moves.
3. **CPU & Battery Constraints**: Re-measuring multi-lane collision clusters (`CalendarLayoutEngine`) on 60Hz/120Hz mobile touch pans drains battery faster than a simple list view.

---

## 4. Code Reuse Opportunities

While presentation layouts should remain specialized, core logic should maximize sharing:

1. **Shared Domain Entities**: Both platforms share `FixedEvent`, `LifeTask`, `WorkSession`, and their draft models in `lib/domain/models.dart`.
2. **Shared State Coordination**: Both platforms route data changes through Riverpod `AppController` and `LifeRepository`.
3. **Pure Math Calculations**:
   - `CalendarLayoutEngine` contains pure coordinate mapping and collision clustering algorithms without any UI dependencies.
   - `CalendarInteractionController` manages LIFO undo/redo stacks, atomic history entries, and occurrence exceptions.
4. **Shared Full-Screen Editors**: Both platforms can invoke `EventEditor` and `SessionEditor` in full-screen modal mode.

---

## 5. Recommended Phased Migration Approach

Rather than immediately replacing `MobileCalendar` or unifying the two codebases, adopt this phased roadmap:

### Phase 1: Clarify Documentation & Verification Invariants (Immediate)
- Update `AGENTS.md`, `docs/ANDROID.md`, and both skills (`todorbit-engineering-quality`, `ultimate-ui-ux`).
- Enforce the **Dual-Platform Entry Point Rule**: Every calendar feature or test must specify whether it targets the Desktop Canvas or Mobile Agenda.
- Label tests using `ThemeData(platform: TargetPlatform.android)` on `CalendarMonthView` as *widget capability tests*, not *mobile production acceptance*.

### Phase 2: Tablet & Foldable Responsive Adaptation (Medium-Term)
- Add a responsive breakpoint in `MobileWorkspace`:
  - When `MediaQuery.sizeOf(context).shortestSide >= 600` (tablets / foldables in landscape), offer users an optional toggle or automatically mount `CalendarView` with touch-adapted configuration:
    ```dart
    CalendarAppearanceConfiguration(
      hourHeight: 72.0,
      dragThreshold: 8.0,
      minItemDurationMinutes: 30,
    )
    ```
  - On standard portrait phones (<600dp), retain `MobileCalendar` as the default agenda.

### Phase 3: Mobile Calendar Agenda Polish (Future)
- Bring select interaction improvements from Beta 16 to `MobileCalendar`:
  - Compact floating auto-dismiss notifications (replacing full-width SnackBar).
  - Quick date swipe navigation in agenda header.
  - Visual current-time indicator in the daily agenda list.
