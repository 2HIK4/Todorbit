# Windows v1.0 final acceptance record

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
| 38 | Windows title bar and application icon | Manual verification required | MethodChannel test and bundle/installer assets pass; maximize/restore, DPI, taskbar, shortcut, and installer visuals need GUI check. |

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
