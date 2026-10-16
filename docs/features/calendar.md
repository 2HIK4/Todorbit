# Calendar

Day, week, and month views currently combine planned task dates, actual deadlines, and fixed events from SQLite. A fixed event has a title, notes, start, and end; create/edit/delete are available in the calendar. Event instants are stored in UTC and shown in local time. Task planned dates and deadlines remain date-only.

Planned work sessions, recurrence occurrences, overlap warnings, and automated conflict blocking are not yet implemented. Fixed events will be hard constraints in Smart Reschedule. Cross-midnight event display is supported by interval overlap logic; DST behavior needs focused tests.
