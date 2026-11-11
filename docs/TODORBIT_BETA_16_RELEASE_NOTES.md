# Todorbit 1.0.19-beta.16 — Calendar Interaction & UI Regression Fixes

Experimental Windows and Android pre-release, build 39. Refines the interactive calendar introduced in Beta 15, resolving interaction quirks, touch conflicts, toolbar layout, and native desktop widget navigation.

### Calendar Interaction & Usability Fixes
- **Accurate Dragging & Viewport Auto-Scroll**: Fixed unexpected upward scrolling on pickup by calculating pointer distance against viewport bounds rather than card-relative coordinates. Auto-scroll triggers strictly within 48px of viewport edges. Continuous 16ms timer ticking keeps dragged items firmly aligned with pointer movement during auto-scrolling.
- **Cross-Day Drag & Drop in Week View**: Full horizontal and diagonal movement across day columns in Week view with global column resolution, live ghost preview on target columns, and atomic date/time commit on release.
- **Dynamic Undo / Redo Toolbar & Shortcuts**: Reactive toolbar buttons update immediately with history availability (`canUndo` / `canRedo`). Autofocus node and shortcut bindings (<kbd>Ctrl</kbd>+<kbd>Z</kbd>, <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>Z</kbd>, <kbd>Ctrl</kbd>+<kbd>Y</kbd>) ensure responsive history operations while preserving native text editing in focused input fields.
- **Compact Auto-Dismiss Notifications**: Replaced persistent full-width banners with a floating 420px notification auto-dismissing after 4 seconds and cleanly replacing prior notices without stacking.
- **Month View Drag Hitboxes & Mobile Touch Protection**: The entire visible card body (10% to 90% width) responds reliably to dragging via opaque hit testing. On mobile platforms (Android/iOS), cards adapt to `LongPressDraggable` (250ms delay, haptic feedback) and adaptive clamping scroll physics, allowing smooth touch scrolling across month rows while preserving deliberate date drag-and-drop.
- **Isolated Ctrl + Mouse Wheel Zoom**: Dedicated `CalendarScrollPhysics` rejects user offset when <kbd>Ctrl</kbd> is pressed, preventing simultaneous timeline scrolling during view zoom transitions. Added 350ms transition debounce to eliminate multi-mode skipping from inertia trackpads.
- **Comfortable Month View Density**: Restored card typography and spacing (28–34px height, 11pt font, 12pt icons, 90px min cell height) for clear, readable month schedules.
- **Unified Toolbar Hierarchy**: Grouped Undo, Redo, divider, and presentation toggle in a single atomic pill container, preventing orphaned icons or wrapping glitches.
- **Polished Current-Time Indicator**: Replaced unlabelled pink line with an intentional primary accent rule, circular pip, live formatted time badge, and accessible tooltip.
- **Windows Tasks Widget Navigation Upgrade**: Updated native Tasks widget earlier/later navigation buttons to 32×32 hit bounds, matching the Calendar widget's arrow geometry, accent color, and Fluent hover outline.

### Verification & Platform Status
- Complete automated regression suite (`test/calendar_interactions_regression_test.dart`) passed (8 end-to-end scenarios).
- Full existing test suites passed (`test/calendar_undo_redo_test.dart`, `test/interactive_calendar_redesign_test.dart`); `dart analyze` reports 0 issues.
- Native widget companion verified via `dotnet run --project experiments/widget-shell-probe -- --self-test`.
- Production-signed Android universal APK built with authorized keystore and 16 KB page-size compatibility.
- This is an experimental pre-release, excluded from the Stable update channel. Windows packages remain unsigned.
