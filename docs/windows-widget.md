# Windows widget integration candidate

The packaged native widget is an integration candidate on
`experiment/windows-widget-shell-host`. It is intentionally **not** promoted
over the Flutter `--widget` development fallback because continuous live
rendering, `Win + D`, normal-window coverage, and Quick Add keyboard input do
not yet have documented positive manual confirmation.

## Build and launch

From the repository root:

```powershell
flutter build windows
build\windows\x64\runner\Release\life_manager.exe
build\windows\x64\runner\Release\life_manager_widget.exe --widget --app-exe build\windows\x64\runner\Release\life_manager.exe
```

The main app's sidebar exposes the same candidate commands. Direct command
examples are:

```powershell
build\windows\x64\runner\Release\life_manager_widget.exe --widget-command show
build\windows\x64\runner\Release\life_manager_widget.exe --widget-command hide
build\windows\x64\runner\Release\life_manager_widget.exe --widget-command quick-add
build\windows\x64\runner\Release\life_manager_widget.exe --widget-command exit
```

The original Flutter implementation remains available only for development:

```powershell
build\windows\x64\runner\Release\life_manager.exe --widget
```

## Behavior and data safety

- The widget is a separate process and remains alive when the main window
  closes. A local named mutex prevents a second native instance.
- The companion opens the existing schema-v3 database, refuses any other
  schema, and never creates or migrates it. Task creation/completion uses
  transactions, UUIDs, and UTC timestamps.
- SQLite database/WAL notifications are debounced in both processes, so task
  changes refresh without a continuous polling or redraw timer.
- Geometry, monitor, size, Today/Inbox view, and theme are stored in
  `%APPDATA%\Life Manager\widget-settings.json`, separate from user data.
- Drag the empty header area to move. Drag the lower-right corner to resize.
  Placement is clamped to connected working areas.
- The tray menu opens Life Manager, toggles the widget, opens Quick Add,
  selects view/theme, exits the widget, or requests complete exit. Launch at
  sign-in is disabled by default and changes only after the user explicitly
  checks the tray item.
- If Explorer destroys the hosted child, the companion retries only creation
  of its own HWND once per second for at most 30 attempts. It never restarts or
  modifies Explorer.

## Manual acceptance checklist

Do not infer these results from build output or screenshots. Record Pass/Fail
and Windows/display details for each item:

1. Leave the widget visible for at least five minutes; verify it never turns
   black, disappears, or requires a capture to repaint.
2. Press `Win + D` twice. Verify the widget remains part of the desktop layer
   and returns correctly.
3. Cover it with a normal application, then reveal the desktop. Verify normal
   windows cover it and it is not topmost.
4. Open Quick Add from the widget and tray. Type, edit, paste, Backspace, and
   submit repeatedly, including after closing and reopening the main app.
5. Create a task in each process and complete it in the other. Verify both
   views update promptly and no duplicate or lost task appears.
6. Open and close the main app at least three times. Verify one widget process
   remains and its tray commands still work.
7. Manually restart Explorer once. Verify the widget returns without Life
   Manager restarting or changing Explorer. This test must be user-directed;
   automated checks do not restart Explorer.
8. Move and resize on every monitor, including different DPI scales if
   available. Restart the widget and verify the saved rectangle remains fully
   visible.
9. Select system, light, and dark themes from both the app and tray; restart
   and verify the persisted appearance and readable contrast.

Only after all acceptance checks pass should the native command replace the
Flutter `--widget` fallback or this branch be merged to the main branch.
