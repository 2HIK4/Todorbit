---
name: todorbit-ui-review
description: Review or improve Todorbit Flutter and native Windows widget UI for visual consistency, responsive layout, accessibility, and real rendered behavior. Use for UI audits or cross-screen design changes; skip for data-only edits.
---

# Todorbit UI review

Start with the affected screen and its shared controls. Read only the relevant parts of `docs/DESIGN.md`, `docs/THEMING.md`, and `docs/CALENDAR_UI_AUDIT.md`. Search `lib/features/shared/` and the existing feature before introducing another control. The app theme is built in `lib/main.dart` from `ThemePalette`; native widget tokens live in `experiments/widget-shell-probe/`. Keep light/dark and custom palette roles aligned.

Use the app's compact Fluent-inspired Windows identity: lavender accent, restrained surfaces, clear focus and selection, keyboard and mouse access. Check spacing, alignment, type hierarchy, text wrapping, popup anchoring, scroll clearance, and visible actions across dialogs, menus, forms, calendar, and navigation. Fix a shared cause across its callers when evidence shows the same defect. Consult Microsoft Fluent guidance for Windows behavior. Use installed `apple-design` selectively for general design principles, translating them to Windows rather than copying platform-specific patterns.

For layout changes, run focused widget tests at ordinary and narrow logical sizes with larger text scale, in light and dark themes where the change is theme-sensitive. Prefer geometry, behavior, and semantics assertions over broad golden snapshots. Inspect a running app with Dart/Flutter MCP and screenshots when available; launch with verified isolated `APPDATA` and `LOCALAPPDATA` first. Check physical window resizing and Windows display scaling when a controllable GUI exists. `flutter test` and offscreen images are automated evidence, not proof of physical DPI, native widget painting, Explorer attachment, mouse input, or popup placement. Report each separately. For native changes use `docs/windows-widget.md`.
