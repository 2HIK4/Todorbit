# Habits and goals

Schema v8 stores habits separately from tasks. A habit measures Yes/No, at
least a numeric target, or at most a numeric limit. It uses a fixed daily,
weekly, selected-weekday, monthly, or yearly date-only schedule with an
interval and optional end day. Users can log and correct historical values,
clear a log with confirmation, mark or remove a rest day, and archive or
restore a habit. Edits to a rule retain existing logs. Future outcomes cannot
be logged. Missing days never create tasks or an overdue task backlog.

The Habits screen shows a selected day's value and real weekly, monthly, and
yearly completion rates. A current day without a log remains pending outside
the denominator; a logged failure counts as due but unsuccessful. Rest days are
excluded. Streaks follow scheduled days and ignore rest days. Entry changes
are audited, and stale edits reject newer records. Habit reminders and native
widget actions await the notification/widget integration milestone.

Goals remain to be implemented. They need targets, milestones, deadlines,
linked work, and progress calculations that avoid double counting.
