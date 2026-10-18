# Calendar

Day, week, and month views currently combine planned task dates, actual deadlines, and fixed events from SQLite. A fixed event has a title, notes, start, and end; create/edit/delete are available in the calendar. Event instants are stored in UTC and shown in local time. Task planned dates and deadlines remain date-only.

Planned work sessions now have separate UTC start/end times and a manually controlled outcome. They appear on the calendar and in task details. A past upcoming session is labeled “Needs confirmation”; a started but unfinished period is labeled “Late start.” Neither label mutates the stored outcome or completes the task.

Calendar views materialize recurring task occurrences only for their bounded
date windows. Each occurrence has its own stable task ID and nominal day;
moving its planned day does not rewrite the rule. Smart Reschedule previews
fixed-event and session collisions and requires a choice for same-series task
date collisions. Cross-midnight event display is supported by interval overlap
logic; DST behavior still needs focused tests.
