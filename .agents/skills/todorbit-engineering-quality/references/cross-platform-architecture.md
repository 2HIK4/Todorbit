# Cross-Platform Architecture: Windows & Android

Todorbit is a unified local-first Flutter application targeting Windows 10/11 and Android (API 26+). This reference defines subsystem boundaries, platform-specific adapters, and the desktop vs mobile navigation architecture.

---

## 1. Application Shell Separation

Startup in `lib/main.dart` branches based on platform and layout flags:

```dart
Platform.isAndroid || widget.mobileLayout
    ? MobileWorkspace(locked: privacy.locked)
    : Workspace(
        openAppearance: widget.openAppearance,
        editWidget: widget.editWidget,
        initialNavigation: widget.initialNavigation,
        legacyImportFile: widget.legacyImportFile,
      )
```

### Critical Architectural Finding: Calendar Divergence
- **Desktop Shell (`Workspace`)**:
  Mounts `CalendarView` (`lib/features/calendar/calendar_view.dart`), which hosts the interactive time-grid timeline, collision avoidance lanes, drag-to-move, edge resizing, cross-day dragging, and zoom transitions (`CalendarDayView`, `CalendarWeekView`, `CalendarMonthView`).
- **Android Shell (`MobileWorkspace`)**:
  Unconditionally mounts `MobileCalendar` (`lib/features/mobile/mobile_calendar.dart`), an independent touch agenda with a compact 54px day cell grid and scrollable card lists.
- **Engineering Implications**:
  1. **No Accidental Parity Assumptions**: Enhancements made to `CalendarView` (such as toolbar pills, zoom controllers, or timeline auto-scrolling) do NOT appear on Android phones.
  2. **Widget Test Platform Injection**: A test executing `CalendarMonthView` wrapped in `ThemeData(platform: TargetPlatform.android)` tests that widget's internal adaptation to Android theme tokens (e.g. `LongPressDraggable`). It does **NOT** prove that production Android users have access to `CalendarMonthView`.
  3. **Feature Delivery**: When designing calendar or scheduling features, verify whether the requirement applies to:
     - Desktop interactive canvas (`lib/features/calendar/`).
     - Mobile touch agenda (`lib/features/mobile/mobile_calendar.dart`).
     - Both (requires dual-surface implementation).

---

## 2. Windows Native Architecture & Companion Host

Windows desktop functionality relies on two main components:
1. **Flutter Windows Runner** (`windows/runner/`):
   - Win32 host managing single-instance mutex, window activation, system tray integration, and native IPC channels.
2. **.NET 10 Companion Host** (`experiments/widget-shell-probe/`):
   - Production desktop widget runner compiling to `TodorbitWidget.exe`.
   - Owns native desktop task & calendar HWND surfaces (`LifeManagerWidget.cs`, `CalendarWidget.cs`).
   - Narrow read/write boundary: directly reads SQLite via `sqlite3.dll`; issues bounded CAS task completions; **never migrates schemas**.
   - Navigation: `WidgetDateNavigation.cs` provides 32x32 hit targets, `DrawCalendarArrow`, and Fluent accent hover/pressed states.

### Windows Native Rules:
- **DPI Awareness**: All native GDI+/DirectWrite drawing must use `LogicalToDeviceUnits` or scale against current monitor DPI (`PerMonitorV2`).
- **Theme Synchronization**: Palette colors (accent, surface, text) are shared via `%APPDATA%\TodoPilot\widgets.json`. Native widgets must react to theme file changes without process restart.
- **Self-Test Verification**: Run `dotnet run --project experiments/widget-shell-probe -- --self-test` to verify native widget geometry and GDI resources.

---

## 3. Android Native Architecture & Kotlin Integration

Android functionality resides under `lib/platform/android/` (Dart) and `android/app/src/main/kotlin/io/github/hik4/todorbit/` (Kotlin).

### Android Subsystems:
1. **Launcher Widgets (`RemoteViews`)**:
   - `AndroidSurfaces.kt`: Renders Tasks and Calendar home screen widgets.
   - Consumes bounded, serialized projection snapshots published by Dart. Never accesses SQLite directly.
   - Task completion routes via `android_widget_action.dart` to the shared `AppController` using a one-time capability token.
2. **Reminders & Alarms**:
   - `AlarmDelivery.kt`, `ReminderRefreshJob.kt`: Uses `AlarmManager` exact alarms with `goAsync()` broadcast receivers.
   - Persists alarm schedules across device reboots via `BOOT_COMPLETED` receiver.
3. **Google Drive OAuth & Storage Access Framework (SAF)**:
   - OAuth identity stored in Android EncryptedSharedPreferences / OS secure storage; short-lived access tokens kept in memory.
   - Database backup/restore uses SAF file picker URIs without requiring full storage permissions.

### Android Native Rules:
- **16 KiB Page Size Compatibility**: Android native shared libraries (.so) in arm64-v8a and x86_64 must be 16 KiB page-aligned. Verify with `python tools/verify-android-artifact.py`.
- **Target API 36 / Minimum API 26**: Respect runtime permissions (e.g. `POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`).
- **Battery & Doze**: Do not spawn persistent foreground services. Use serialized work jobs and alarm intent receivers.
