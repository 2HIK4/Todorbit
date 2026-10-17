# Scheduling and Smart Reschedule

Keep scheduled dates, deadlines, planned sessions, actual time, and fixed events
separate. Smart Reschedule never changes completion, deadlines, actual starts,
session outcomes, or fixed events.

## Implemented

Task-list and Calendar entry points open the real Smart Reschedule workspace.
It supports Move, Shift (positive or negative), Push, Pull, Swap, Reorder,
Repack, and Split on compatible selections. Task operations remain date-only.
Session operations preserve duration and use UTC instants. Push and Pull operate
on the reviewed selection in the current view/project/category/calendar scope;
no persistent sequence is implied. Reorder assigns the selected task order to
successive local days, or packs selected sessions sequentially from the chosen
instant. Split creates another work session, not a subtask.

Every operation first creates an immutable, non-writing proposal. The preview
shows before/after values, affected items, warnings, hard conflicts, and lets the
user exclude changes. Apply requires explicit confirmation, rechecks
`updated_at` plus the reviewed scheduling fields, and atomically writes all
changes and focused history. Any stale item rejects the whole apply.

Persisted availability starts empty: Life Manager does not invent working
hours. Users can enable one weekly window per weekday in the current editor and
add unavailable or custom-hour date exceptions. Storage and the engine support
multiple windows. Repack respects availability, exceptions, fixed events,
unselected sessions, a user-entered buffer (default 0), the 15-minute minimum,
capacity, task locks, completion state, and deadline warnings. Move and Shift
detect event/session collisions; a user may explicitly turn an intentional
overlap into a warning and then acknowledge it.

Scheduling history records stable operation/change IDs, source (manual or Smart
Reschedule), scope, timestamps, target IDs, before/after schedule fields, and
optimistic versions. Flutter task/session edits and native-widget planned-date
edits are manual history entries. Undo and Restore Previous/Original are
previewed and create new history; they never erase old entries. A target is
restored only when its current schedule still equals the selected historical
after-state, so a later manual adjustment is protected. Completed, started,
cancelled, and locked work is preserved.

## Deferred boundaries

Dependencies, persistent task sequences, and recurring occurrences are still
deferred product models. Consequently there is no dependency-order validation
or drag-to-reorder sequence storage yet. When recurrence arrives, history
targets must reference occurrence IDs and reschedule one occurrence by default
without editing its recurrence rule.
