# Windows widget

Investigate an integrated native companion that stays on the desktop under `Win + D` while ordinary windows may cover it. The companion must own its lifecycle independently of the main Flutter window. Verify desktop attachment manually on actual Windows, including Explorer restart, display changes, DPI, and multiple monitors. Undocumented shell behavior is a compatibility risk. Never claim `Win + D` support based only on automated tests. Do not change startup or registry settings without explicit approval.

## Feasibility prototype

The same Windows executable accepts `--widget` and starts a separate Flutter process with a small task UI. The native runner changes that window to a child of the desktop HWND using documented `SetParent`. The process exits if parenting fails, rather than falling back to an ordinary window. This approach does not send undocumented Explorer messages or change Explorer configuration.

Run `build\windows\x64\runner\Release\life_manager.exe --widget` from the repository. The prototype can list Today/Inbox tasks, add a task, complete a task, refresh, and open the main app. Closing the main app does not close the widget process. It currently has no drag/resize persistence, timer, tray, automatic refresh, or startup behavior.

Native parenting succeeds in an automated process smoke check, but visibility, layering, click behavior, and survival of `Win + D` remain **unverified**. The desktop HWND may not provide the desired Explorer layering. Manually test by launching with `--widget`, pressing `Win + D`, covering it with a normal window, interacting with a task, and restarting Explorer. Do not expose this as a completed widget feature until these checks pass.
