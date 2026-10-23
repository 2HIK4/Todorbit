# Calendar

Schema v21 stores a nullable default event color on each category and a JSON
list of optional details on each event. A separate table keeps reusable custom
detail-type names; deleting a type does not erase labels or values already
saved on events. Existing location text migrates into a Location detail and
the old column remains for native compatibility. Events have no project link,
so project colors do not currently apply. An explicit event color overrides
the category color. The event editor supports preset and HEX colors, a color
wheel, live duration, and clear Never/On date recurrence ending controls.
Occurrence overrides and split series carry details forward.

The per-profile appearance settings retain the last selected Day/Week/Month
view and the first weekday. Week starts Sunday until a user changes it. The
setting reorders Calendar Week/Month, date pickers, recurrence weekday rows,
habit weekly summaries, and weekly availability. Month has weekday headers;
day details open in a centered dialog.

Schema v16 adds recurring events to the existing fixed-event table. Daily,
weekly, selected-weekday, monthly, and yearly rules use local nominal dates;
selected weekdays and an inclusive last date support semester lectures. The
repository projects only the requested window and persists cancellations and
manual changes by original occurrence date. This and future edits split the
series in one transaction; earlier dates retain their previous details.
Individual cancellation can be restored, and ending a series leaves earlier
dates visible. The Day, Week, and Month filter switches between Events, Tasks
(including planned work sessions), and Both, with a per-user saved preference.
Schema v20 delivers optional event reminders through the packaged Windows tray
companion. The editor offers at-start, 5, 15, 30, or 60 minutes before; it
starts the companion when saving a reminder. Startup also starts the companion
when saved event reminders exist. A per-occurrence SQLite claim prevents repeat
delivery, including after restart. Cancelled occurrences do not alert, and
manual occurrence changes use their changed time and reminder. The control is
disabled when the native companion is unavailable. Windows notification
visibility and delivery still require manual acceptance.

Event cards mark overlaps with other active events or planned work sessions.
Recurring task plan activities appear as a second calendar line on the
scheduled day.

Day, week, and month views currently combine planned task dates, actual deadlines, and fixed events from SQLite. A fixed event has a title, notes, start, and end; create/edit/delete are available in the calendar. Event instants are stored in UTC and shown in local time. Task planned dates and deadlines remain date-only.

Planned work sessions now have separate UTC start/end times and a manually controlled outcome. They appear on the calendar and in task details. A past upcoming session is labeled “Needs confirmation”; a started but unfinished period is labeled “Late start.” Neither label mutates the stored outcome or completes the task.

Calendar views materialize recurring task occurrences only for their bounded
date windows. Each occurrence has its own stable task ID and nominal day;
moving its planned day does not rewrite the rule. Smart Reschedule previews
fixed-event and session collisions and requires a choice for same-series task
date collisions. Cross-midnight event display is supported by interval overlap
logic; DST behavior still needs focused tests.
