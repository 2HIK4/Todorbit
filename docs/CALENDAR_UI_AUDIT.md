# Calendar and cross-app UI audit — 2026-10-23

## Scope and findings

- The event editor used a top-clipped floating Title label, a narrow scroll viewport, and select menus that hid their triggers. The form now reserves space above the first field and beside its scrollbar; Category and Color use anchored menus with a bounded, scrollable Color menu.
- The same dialog padding pattern occurred in Task, Session, Habit, Goal, recurring Series, and Advanced Search editors. These forms now reserve top and trailing scroll space. Habit and Goal dialogs also use a shorter content-aware height. Templates, Saved Views, Privacy, theme customization, and several other selects retain their existing layouts; those areas need a physical cross-app review before claiming full consistency.
- Calendar Week and Month, date pickers, recurrence weekday controls, habit summaries, and weekly rescheduling now share the profile's first weekday. Sidebar order and Calendar mode are also profile settings.
- Schema 21 stores category default event colors, event detail snapshots, and reusable custom detail types. Legacy Location values migrate to Location details. An event's explicit color wins over its category default; there is no event-to-project relationship in the current model.
- Native widget schema compatibility was raised to 21. Its painted UI was not changed by this work.

## Verification evidence

Automated: `flutter analyze --no-pub` passed; focused calendar, layout, recurrence, and backup tests passed; the full serial Flutter suite passed all 217 tests. The native .NET Release build had zero warnings or errors, the Windows Flutter Release build succeeded, and source and packaged `TodorbitWidget.exe --self-test` both passed. The isolated Release executable stayed alive and created its own SQLite profile database. Tests cover preference and SQLite reopen, migration, backup, sidebar reorder, Month restoration, day preview, event color selection, duration, and a narrow seven-day row.

GUI: An isolated Flutter Driver debug Windows session at 1264 × 681 showed the dark and light Today, Calendar Month, Event editor, Habit editor, Settings, and sidebar-order dialog. Month remained selected after navigation and a hot restart. The Event Title label was fully visible when focused; the Category and bounded Color menus opened below their fields. A custom `#12AB34` color changed the live preview and returned to the editor with a matching indicator. A Location detail row appeared after selecting it. Scrolling the Event form exposed the 1-hour duration, seven equal recurrence weekday buttons, and the Never/On date selection. Clicking a Month cell opened a centered day dialog. The initial color-dialog close exposed a disposed-controller Flutter assertion; the dialog now owns that controller, and the same interaction was repeated without new process errors. The available Computer Use native control service could not attach to the Release window. Debug screenshots do not establish Release pixels or native widget behavior.

Follow-up from `e10fe1a`: At 1264 × 681, the isolated debug GUI was used to open dark/light New/Edit Habit and dark New/Edit Goal, scroll the Habit and Event forms, create and reopen an Event and Task, and inspect Advanced Search, Templates manager, and Settings. The 510 px Habit dialog hid its End day control below the visible area; New and Edit now use 550/580 px caps and show that control at this size. Advanced Search select labels crowded adjacent fields; 12 px gaps corrected the inspected dark view. A 360 × 600 logical widget test at 1.5× text scale exposed Habit select and footer overflows; a 430 × 620 test at 1.3× exposed Advanced Search select overflows. Selects now constrain their content and Habit, Goal, and Search share a wrapping action bar. These are debug GUI observations and widget-test results, not physical narrow-window or Windows DPI checks. The native editor's narrow light offscreen capture showed scrollbar clearance, but native mouse input, Explorer attachment, and DPI remain unverified.

Follow-up gates: `flutter analyze --no-pub` found no issues; the focused dialog layout test and all 221 serial Flutter tests passed. The full suite emitted the existing nonfatal `workspace_test.dart` scroll hit-test warning. Native .NET Release built with zero warnings/errors; source and packaged widget self-tests passed. `flutter build windows --release --no-pub` succeeded. The isolated Release executable remained alive for six seconds and created `TodoPilot/life_manager.sqlite` under a disposable `%APPDATA%` root; it was then stopped. This is startup evidence, not Release visual acceptance.

The final isolated debug GUI pass created and reopened a Work Session, created a weekly Event and opened its occurrence/series scope, saved a Task template and opened its populated Apply dialog, and created and edited a Saved View. Save Template's explanation touched its floating name label; Apply Template's date button touched the Category label. Both gaps were fixed and the same dialogs were reopened with clear labels. Focused Template tests now assert those gaps, including the project-name variant. These checks used the normal-size debug GUI; Release, narrow-window, and physical DPI behavior remain open.

## Original-issue checklist

`PASS` means the implementation has relevant test or live GUI evidence. `PARTIAL` identifies remaining scope; `UNVERIFIED` means an implemented behavior still needs physical interaction.

| ID | Result | Evidence or remaining work |
|---|---|---|
| 01 Title floating label | PASS | Focused dark/light GUI screenshots and widget layout test show the full label. |
| 02 Event scrollbar overlap | PARTIAL | New and Edit forms scrolled in the debug GUI; the trailing gap remains clear in widget layout coverage. Physical scrollbar drag and DPI checks remain. |
| 03 Category dropdown | PASS | Anchored below the field in GUI and widget test. |
| 04 Color dropdown | PASS | Bounded anchored menu and scroll observed in GUI. |
| 05 Sidebar order | PASS | Drag and arrow widget test; profile reopen test; GUI configuration dialog. |
| 06 Last Calendar view | PASS | Month survived navigation and hot restart in GUI; profile reopen test. |
| 07 Custom event color | PASS | Wheel, HEX, validation, live preview in GUI; custom integer persisted through SQLite reopen. |
| 08 Category/project defaults | PASS | Category inheritance and explicit override persist in tests. Project inheritance is inapplicable because events have no project link. |
| 09 Equal recurrence weekdays | PASS | Shared seven-column control has narrow-width widget coverage. |
| 10 Configurable week start | PASS | Sunday Month grid in GUI; setting and weekday order persist in tests. |
| 11 Live event duration | PASS | Full-date and all-day calculation tests; editor renders calculated label. |
| 12 Recurrence ending | PASS | Never/On date menu and resulting value observed in the debug GUI; existing recurrence tests pass. |
| 13 Centered day dialog | PASS | Centered placement observed in the debug GUI; Escape handling still needs a physical keyboard check. |
| 14 Event Details | PASS | GUI added a Location row; custom catalog, event snapshot, occurrence, migration, and backup tests pass. |
| 15 Color indication | PASS | Name/HEX and matching circle observed in GUI. |
| 16 Icon beside Title | PASS | Dark/light Event editor screenshots show both in one row. |
| 17 Month weekday headers | PASS | Sunday-to-Saturday headers align with columns in dark/light GUI. |
| 18 Habit dialog spacing | PASS | Dark/light New and populated Edit dialogs were interacted with in the debug GUI; End day is visible and the form scrolls. New/Edit narrow layouts pass the 360 × 600, 1.5× text-scale widget test. Physical narrow/DPI review remains in manual acceptance. |
| 19 Related dialog defects | PARTIAL | Advanced Search and Template label collisions were fixed and rechecked in the debug GUI. Task, Goal, Event, Habit, Session, Templates, Saved Views, and Settings had debug GUI inspection. Backup dialogs, native forms, Release, and physical narrow/DPI review remain. |
| 20 New/Edit consistency | PASS | New and populated Edit Event, Task, Habit, Goal, Session, and Saved View variants were opened in the isolated debug GUI; recurring Event scope and Template Save/Apply were also inspected. Habit/Goal narrow variants pass widget tests. Physical narrow/Release variants remain in manual acceptance. |

## Remaining manual acceptance

Use a disposable `%APPDATA%` and `%LOCALAPPDATA%` profile. Launch the Windows Release executable and inspect at normal and narrow sizes in dark and light themes, including increased Windows text scale and DPI. Open New and Edit Event; focus the top Title; mouse-wheel and drag the form scrollbar; open Category and Color near the top and bottom; enter invalid and valid HEX; add, edit, and remove Details; expand recurrence, change weekdays and ending, and check duration across midnight. Click a Month cell and confirm the dialog is centered and Escape closes it. Reorder sidebar items, restart, and inspect each destination and selected state. Open New and Edit Task, Habit, Goal, Series, Session, Templates, Saved Views, Settings, Search, and backup dialogs for label, popup, scrollbar, and footer clearance, especially 1.5× Windows text scaling. Run the native widget checklist in `docs/windows-widget.md`, including Explorer attachment, mouse input, DPI, and menus. These physical checks remain open because the native computer-control service exposed no Release or Explorer windows in this session.
