# Windows v1.0 final acceptance record

## TodoPilot 1.0.2 update (2026-10-19)

The 1.0.2 Release build and packaged widget self-test pass. The final portable
ZIP's extracted widget self-test also passes. The isolated 1.0.2 GUI process
started, but the Windows inspection tool did not enumerate its window. The
transparent in-app sidebar mark is therefore present in source and package but
still needs direct dark/light visual acceptance at 24 px. Rows 2–25 and 27–29
below retain their prior manual status; the 1.0.2 installer, registered upgrade,
uninstall, taskbar/shortcut icons, widget composition/input/DPI, and Windows 10
remain untested. Do not treat the older 1.0.1 GUI observations as a 1.0.2 pass.

Status updated 2026-10-19. Tests use disposable profiles. `Passed` means this
checkpoint's actual Windows Release UI was observed. Automated tests are
reported separately in `PROGRESS.md` and do not turn an unobserved GUI flow into
a manual pass.

| # | End-to-end flow | Status | Evidence or next check |
|---|---|---|---|
| 1 | First launch | Passed | Release window opened on verified isolated APPDATA/LOCALAPPDATA; empty Today rendered. |
| 2 | Create categories, projects, tasks | Manual verification required | A task was created in the final Release app; category/project creation still untested. |
| 3 | Edit, complete, reopen, delete tasks | Manual verification required | Full Release flow untested. |
| 4 | Sequences and dependencies | Manual verification required | Full Release flow untested. |
| 5 | Reschedule preview, cancel, apply | Manual verification required | Prior narrow preview inspection; full Release flow untested. |
| 6 | Schedule Undo and restoration | Manual verification required | Full Release flow untested. |
| 7 | Recurring tasks and series editing | Manual verification required | Full Release flow untested. |
| 8 | Recurrence exceptions and collisions | Manual verification required | Full Release flow untested. |
| 9 | Habit progress | Manual verification required | Full Release flow untested. |
| 10 | Goals and task links | Manual verification required | Full Release flow untested. |
| 11 | Timers and manual work | Manual verification required | Full Release flow untested. |
| 12 | Task templates | Manual verification required | Full Release flow untested. |
| 13 | Saved views | Manual verification required | Full Release flow untested. |
| 14 | Reports and statistics | Manual verification required | Empty report was inspected at an earlier checkpoint; populated result untested. |
| 15 | Reminders | Manual verification required | Actual Windows tray delivery untested. |
| 16 | Archive and restore | Manual verification required | Partial earlier inspection; full Release flow untested. |
| 17 | Trash recovery | Manual verification required | Full Release flow untested. |
| 18 | Database export | Manual verification required | Native file picker untested. |
| 19 | Database import preview | Manual verification required | Native file picker untested. |
| 20 | Next-launch restore | Manual verification required | Native Release flow untested. |
| 21 | Managed attachment add/open | Manual verification required | Native picker and opener untested. |
| 22 | External file, folder, URL links | Manual verification required | Native picker and opener untested. |
| 23 | Missing external resource | Manual verification required | Full Release flow untested. |
| 24 | Enable, unlock, relock privacy | Manual verification required | Disabled dialog visually inspected; computer-use rules barred changing privacy settings through UI automation. |
| 25 | Widget respects lock | Manual verification required | Native self-test covers lock-state decisions; real two-process UI untested. |
| 26 | Restart and persistence | Passed | A task created in the isolated Release app retained its UUID and planned date in SQLite and appeared on Today after a full app restart. |
| 27 | Main app/widget independent lifecycle | Manual verification required | Previously accepted widget build; privacy changes require retest. |
| 28 | Theme synchronization | Manual verification required | Previously accepted widget build; final package requires retest. |
| 29 | Widget after Win+D | Manual verification required | Computer-use rules bar Windows-key automation; user must perform. |
| 30 | Packaged or installed application | Manual verification required | Feedback Round 2 Release bundle opened and its 15 files were rebuilt into the Inno Setup 7.1.0 installer; bundle audit found no database or personal files, and the packaged widget self-test passes. Installed flow remains untested. |
| 31 | New profile versus existing profile | Manual verification required | Disposable database tests pass; newly installed profile and existing personal profile need GUI comparison. |
| 32 | Recurring lecture and single-date cancellation/restoration | Manual verification required | Repository and widget tests pass; isolated Release GUI flow untested. |
| 33 | Event reminder balloon | Manual verification required | Native self-test covers one-off, selected weekday, cancellation, and duplicate claim; actual Windows tray delivery untested. |
| 34 | Task/category/project icon selection | Manual verification required | Persistence tests pass; visual size and reset behavior need Release GUI check. |
| 35 | Checklist and one-level subtask | Manual verification required | Persistence and widget tests pass; full Release GUI flow untested. |
| 36 | Progressive recurring study plan | Manual verification required | Assignment, skip, edit, restart, split, migration, and Calendar/editor tests pass; full Release GUI flow untested. |
| 37 | Focus stopwatch and sidebar mini timer | Passed | In the isolated Feedback Round 2 Release profile, focus visibly advanced from 00:00:00 to 00:00:06, the sidebar mini timer updated, Stop produced a 00:00:14 timer log and stopped state, and the task stayed In progress. Pause/resume still has automated coverage and needs a direct Release visual pass. |
| 38 | Windows title bar and application icon | Partially passed | The final extracted 1.0.1 ZIP visibly shows the transparent outlined orbit in the title bar. Resource 102 is the separate window icon; resource 101 remains the original black-tile icon. Taskbar selection, maximize/restore, DPI, shortcuts, and installer visuals need GUI checks. |
| 39 | Orbit icon in Release app | Partially passed | The primary executable ICO is byte-identical to the previous committed black-tile orbit; the rebuilt executable's extracted associated 32 px icon remains black and white. The new outlined window ICO has 16/20/24/32/48/64 px entries. Start menu, File Explorer, desktop shortcuts, and taskbar still need direct visual checks. |
| 40 | Visual color wheel and HEX | Passed | At 1266×713, the hue ring, saturation/value square, preview, HEX field, and Cancel/Reset/Confirm controls fit without overflow. Mouse wheel selection changed preview and HEX; keyboard HEX edit changed preview and wheel. |
| 41 | Separate palettes and restart persistence | Passed | In an isolated profile, light accent changed to `#BD561A`; saved settings and a full TodoPilot restart retained it while dark accent stayed `#B9A4F4`. Automated persistence test also passed. |
| 42 | Native widget opacity, layout lock, and desktop behavior | Partially passed | Initial isolated GUI launch failed to create the layered child. A Windows-aware manifest fixed creation; read-only inspection then found the visible `WS_EX_LAYERED` child under Explorer at the intended (1520,24) screen position across two monitors. Actual 0/30/70/100% alpha over wallpapers, Win+D, context menu, task hit testing, DPI resize, and independent lifecycle still need direct GUI acceptance. |
| 43 | Portable ZIP and installer | Partially passed | The final 1.0.1 ZIP has 26 entries and no database, settings, backups, logs, or keys. Two extracted copies launched in one disposable application-data root and created separate empty profiles. The Inno Setup installer compiled from the checked Release bundle; no installer installation was performed. Hashes are in `docs/PROGRESS.md`. |
| 44 | Portable persistence and separate copies | Passed | An extracted copy opened with zero tasks, fixed events, goals, habits, work sessions, timer runs, and time entries. One task created in its UI remained after reopening; a second extracted copy opened with zero tasks in a different profile. |
| 45 | Old Life Manager data on fresh start | Partially passed | The unmarked Release executable opened a fresh empty database beside a disposable legacy database with one task and offered a reviewed import. The actual fresh installer operation is untested. |
| 46 | Existing TodoPilot upgrade and widget profile | Partially passed | A disposable legacy database plus valid upgrade marker selected the one-task legacy profile in the Release app; the native widget wrote settings there. Two final packaged portable widgets ran concurrently and commands exited only the matching copy. Actual registered-installer upgrade remains untested. |
| 47 | Uninstall and reinstall | Manual verification required | Source has no personal-profile uninstall deletion. No disposable Windows user or VM was available for an actual installer/uninstaller run; data retention after that operation is unverified. |

The privacy dialog opened in the rebuilt Release app with the default disabled
state and no visible layout overflow at 1266×713. It was closed without
changing settings. A final Release UI run created a disposable Today task and
verified it after restart. No personal database was opened or migrated.

Feedback Round 2 also inspected the rebuilt dark-theme Release at 1266×713 in
a disposable profile. Today, the reorganized new-task editor, empty Calendar,
task row, live focus dialog, stopped work log, and mini timer rendered without
visible overflow. Light-theme Today and its task row also rendered with readable
contrast and matching native caption colors. A disposable task and a short timer
log were created only in that isolated profile. Narrow restored windows,
125%/150% DPI, populated secondary views, and the native widget remain manual
visual checks.
