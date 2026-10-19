# Customization extension points

- Add a semantic color in `lib/domain/appearance.dart`, its defaults and validator, then wire it to Flutter `ColorScheme` in `lib/main.dart` and native `WidgetPalette` in `experiments/widget-shell-probe/LifeManagerWidget.cs`. Bump the JSON version when changing required keys and provide a safe migration.
- Create a theme by exporting a version 1 JSON file from Appearance, editing allowed HEX values, and importing it. Check contrast in both modes. Built-in examples belong in code; community themes remain data.
- Add an icon in `lib/features/shared/icon_picker.dart`. Keep a consistent stroke and label icon-only controls.
- Add a Settings section in `lib/features/workspace/workspace.dart`; place its UI in `lib/features/settings/`.
- Add a page by extending `WorkspaceView`, routing in `Workspace._mainPanel`, and adding a sidebar entry. Put UI in `lib/features/`, domain data in `lib/domain/`, and SQLite writes in `lib/data/` repositories.
- Add a feature with disposable database tests. Maintain stable UUIDs, UTC timestamps, forward migrations, and explicit user choice for completion or rescheduling.
- Edit native widget colors in `WidgetPalette` and geometry/input in `NativeDesktopWidgetHost.cs`; preserve Explorer child hosting, IPC, privacy lock, and main-app independence. Run its `--self-test` and the manual checklist in `docs/windows-widget.md`.

Keep `AGENTS.md` and `docs/PROGRESS.md` current for future contributors and coding agents.
