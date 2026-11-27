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
- **Theme Synchronization & Translucent Contrast**: Palette colors (accent, surface, text) are shared via `%APPDATA%\TodoPilot\widgets.json`. Native widgets must react to theme file changes without process restart, preserve surface alpha in hover/selection blends without mutating configuration maps, and avoid symmetric 4-way white halos in `WidgetText`.
- **Smooth Pixel Scrolling & Idle Timer Hygiene**: Share `WidgetScrollAxis` between Tasks and Calendar widgets, honor `MouseWheelScrollLines` and `SPI_GETCLIENTAREAANIMATION`, keep offscreen rows accessible via keyboard/UIA, and guarantee the 16 ms animation timer stops cleanly when settled (`0` idle repaints) and disposes cleanly in `WmDestroy`.
- **Self-Test Verification**: Run `.\tools\dev\native-self-test.ps1 -Executable experiments/widget-shell-probe/bin/Release/net10.0-windows/TodorbitWidget.exe -IncludeLifecycle -IncludeBenchmark` (and `--capture-matrix` for wallpaper theme contrast) to verify native widget geometry, scroll quiescence, and GDI resource disposal.

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
4. **Android Shared Files Inbox & Intent Ingestion**:
   - `ShareReceiverActivity.kt`: Dedicated lightweight activity with `Theme.Translucent.NoTitleBar`, `noHistory="true"`, and `excludeFromRecents="true"`.
   - Handles `ACTION_SEND` and `ACTION_SEND_MULTIPLE` without booting the Flutter engine on cold start.
   - Immediately streams `content://` URIs via `ContentResolver` to app-private staging storage (`TodoPilot/shared_inbox/files/`) before temporary URI grants lapse.
   - Manifest `shared_inbox.json` maintains durable file metadata, SHA-256 duplicate detection, and size limits (32 MiB).
   - Minimal interruption UX: posts a brief Toast confirmation and immediately calls `finish()`, returning the user to the sending app without forced task creation.
   - If Flutter engine is warm, notifies `MainActivity` via MethodChannel `sharedInboxUpdated` to update UI immediately.

### Android Native Rules:
- **16 KiB Page Size Compatibility**: Android native shared libraries (.so) in arm64-v8a and x86_64 must be 16 KiB page-aligned. Verify with `python tools/verify-android-artifact.py`.
- **Target API 36 / Minimum API 26**: Respect runtime permissions (e.g. `POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`).
- **Battery & Doze**: Do not spawn persistent foreground services. Use serialized work jobs and alarm intent receivers.
- **AppWidget lifecycle and dates**:
  - Keep framework-only receivers non-exported when their senders are the system/own UID; an intent filter is not access control. Validate actions before starting work. Export only for a demonstrated external sender with appropriate protection. See [receiver semantics](https://developer.android.com/guide/topics/manifest/receiver-element) and [receiver security](https://developer.android.com/privacy-and-security/risks/insecure-broadcast-receiver).
  - Check [implicit broadcast exceptions](https://developer.android.com/develop/background-work/background-tasks/broadcasts/broadcast-exceptions) for the actual target SDK. `DATE_CHANGED` is not an exempt manifest delivery mechanism for target 26+; use an explicit alarm and lifecycle reconciliation.
  - `setAndAllowWhileIdle` is inexact and can still be batched/delayed in Doze. For a justified date refresh, bound wakeups to installed widgets, reuse one immutable explicit PendingIntent, cancel when none remain, and recompute civil midnight in the current zone. Never add exact-alarm permission just for widget dates. See [AlarmManager](https://developer.android.com/reference/android/app/AlarmManager#setAndAllowWhileIdle(int,%20long,%20android.app.PendingIntent)).
  - Distinguish Follow Today from deliberate browsing. Selecting Today clears a pinned date; do not silently expire an active selection without an explicit product rule. Preserve legacy per-instance preferences whose provenance is unknown.
  - Restore schedules after boot/unlock and own-package replacement, and reconcile on clock/zone changes, widget creation and app resume. Use application context for queued work and keep widget-only refresh separate from reminders/Sync jobs. Verify actual device/upgrade behavior separately from host policy tests.


---

## 4. Desktop OAuth & Cloud Release Configuration Gate

Google Drive and Smart Sync require platform-specific OAuth authentication:
- **Windows Desktop**: Uses desktop loopback OAuth with PKCE. Requires compile-time flags (`GOOGLE_DRIVE_ENABLED=true` and a registered Desktop OAuth Client ID).
- **Android**: Uses Google Play Services platform auth (`GOOGLE_DRIVE_ANDROID_ENABLED=true` default).

### Windows Release Packaging Gate:
- Windows release builds must embed an active Google Drive release configuration.
- `tools/google-drive-release-config.ps1` resolves the configuration via `Resolve-GoogleDriveReleaseConfigPath` (checking explicit `-ConfigPath`, `$env:TODORBIT_GOOGLE_DRIVE_CONFIG`, a machine-local maintainer secrets override when building from the primary checkout, and finally repo-relative `config/google-drive.json`).
- `Assert-GoogleDriveReleaseBundle` verifies that `googleDriveEnabled: true` in the output `todorbit-build.json` metadata. Packaging scripts (`build-windows-release.ps1`, `installer/build-installer.ps1`, `tools/build-portable.ps1`) fail immediately if `googleDriveEnabled` is false, unless `-AllowDisabledDrive` is explicitly passed for test builds.
- This gate prevents accidental deployment of disabled cloud integration builds where users see "Google Drive is unavailable in this build".

---

## 5. Flutter Test Harness Diagnostics: Fake Async, Native I/O & Drawer Scrolling

When writing or executing widget integration tests in Todorbit (`testWidgets`), adhere to these invariants to prevent test hangs, false timeouts, and navigation failures:

### 1. FakeAsync Zone & Native File System I/O:
- `testWidgets` executes within a `FakeAsync` zone that virtualizes microtasks and timers (`pump`, `pumpAndSettle`).
- Native asynchronous file system I/O from `dart:io` (`File.readAsBytes()`, `FileSystemEntity.type()`, `source.stat()`) runs on native OS thread pools outside Dart's virtual event loop.
- If called directly in fake async without `tester.runAsync()`, the completion future will never resolve, causing the test isolate to hang until the harness hits its maximum timeout (e.g., 10 minutes).
- **Rule**: Any operation that performs native file I/O or multi-step persistence (such as `LifeRepository.attachManagedFile` or `LifeRepository.addDraftResources`) MUST be wrapped in:
  ```dart
  await tester.runAsync(() async {
    await repository.attachManagedFile(task.id, file);
  });
  ```

### 2. Eliminating Infinite Animation Deadlocks:
- An active `CircularProgressIndicator` uses an unconstrained spinning `AnimationController`.
- Calling `await tester.pumpAndSettle()` while a spinner is animating will loop until timeout because frames never settle.
- **Rule**: Implement synchronous initialization/hydration (`loadSync()`) where practical so the widget mounts in an already-loaded state on frame 1. For asynchronous paths, pump discrete frames (`await tester.pump(const Duration(milliseconds: 50))`) instead of unconstrained `pumpAndSettle()`.

### 3. Navigation Drawer Lazy Layout:
- `MobileWorkspace`'s side navigation drawer builds items in a lazily evaluated `ListView`. Items positioned below the viewport fold (e.g. `Shared Files`, `Archive and Trash`) are NOT constructed until scrolled into view.
- Attempting to locate them directly via `find.text('Shared Files')` will fail with 0 matches.
- **Rule**: Always use `tester.scrollUntilVisible` scoped to the `Drawer`'s `Scrollable`:
  ```dart
  final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold).first);
  scaffoldState.openDrawer();
  await tester.pumpAndSettle();

  final item = find.text('Shared Files');
  await tester.scrollUntilVisible(
    item,
    200,
    scrollable: find.descendant(of: find.byType(Drawer), matching: find.byType(Scrollable)).first,
  );
  await tester.tap(item);
  await tester.pumpAndSettle();
  ```
