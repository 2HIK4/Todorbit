# Windows v1.0 final acceptance record

Status recorded 2026-10-18. Tests use disposable profiles. `Passed` means this
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
| 30 | Packaged or installed application | Manual verification required | Unpacked Release opened and Inno Setup 7 installer compiled; installed flow untested. |

The privacy dialog opened in the rebuilt Release app with the default disabled
state and no visible layout overflow at 1266×713. It was closed without
changing settings. A final Release UI run created a disposable Today task and
verified it after restart. No personal database was opened or migrated.
