# In-app hotkeys

Settings → Hotkeys shows the current mapping, captures a new Ctrl combination,
checks conflicts, and manages named presets. Shortcuts apply only while the
Todorbit workspace has focus; they do not register Windows global hotkeys.
Plain typing, Windows-key combinations, Ctrl+Alt combinations, and the usual
Ctrl+A/C/V/X/Z/Y editing keys are reserved.

| Default | Action |
|---|---|
| Ctrl+N | New task |
| Ctrl+K | Quick Search |
| Ctrl+Shift+F | Advanced Search |
| Ctrl+1 | Today |
| Ctrl+2 | All Tasks |
| Ctrl+3 | Calendar |
| Ctrl+4 | Anytime |
| Ctrl+9 | Task display and defaults Settings |
| Ctrl+Shift+P | Start Focus for the selected open task, or stop the active timer |
| Ctrl+R | Refresh current view |

## Calendar shortcuts

When the Calendar view has focus:

| Shortcut | Action |
|---|---|
| Ctrl+1 | Day view |
| Ctrl+2 | Week view |
| Ctrl+3 | Month view |
| T | Jump to today (when not typing in a text field) |
| Ctrl+Z | Undo last calendar reschedule or resize |
| Escape | Cancel active drag or resize gesture |
| Ctrl+Wheel Up | Zoom in (Month → Week → Day anchored at pointer) |
| Ctrl+Wheel Down | Zoom out (Day → Week → Month anchored at pointer) |

Global Ctrl+1..4 shortcuts switch workspace navigation views (Today, All Tasks, Calendar, Anytime) when outside the Calendar view.

Editing the Default preset creates a Custom preset. Reset one restores that
action's default if no other action uses it. Reset all selects Default and
keeps saved custom presets. Settings are stored per active profile in the
existing `appearance-settings.json` file.
