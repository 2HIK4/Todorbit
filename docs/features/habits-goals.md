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

Schema v9 stores goals with targets, start days, optional deadlines, manual
progress adjustments, non-additive milestone checkpoints, and reversible
completion and archive state. Users can edit milestones and mark them done
without adding the same progress a second time. Goal progress combines the
manual ledger with completed linked tasks/projects and successful linked
Yes/No habit days. A task linked directly and through its project contributes
once. Linked work starts on the goal's start day, and reopened tasks leave
the current total. Only Yes/No habits can link because their outcome remains
well-defined when the habit target changes. The progress dialog shows manual
adjustment history and current linked contributions. A relevant due-soon goal
entry appears on Today. Milestone completion and goal completion remain
explicit actions, even when a numeric threshold is reached.
