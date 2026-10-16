# Scheduling and Smart Reschedule

Keep scheduled dates, deadlines, planned sessions, actual time, and fixed events separate. A deterministic engine will read availability, exceptions, durations, buffers, locks, dependencies, events, and deadlines. Operations include move/shift/push/pull/reorder/swap/repack/split and sequence scheduling. Return a preview of hard conflicts and overridable warnings before any transactional apply. Record before/after history and preserve later manual edits during restore by default.

Test no-slot explanations, protected events, deadline and dependency warnings, multi-selection atomicity, undo, and restoration after manual edits.

## Current implementation

Fixed events and planned work sessions are persisted independently. Session outcomes are explicit; passage of time only creates “Late start” or “Needs confirmation” indicators.

A pure deterministic repack engine now returns proposed before/after session placements and issues without writing data. It respects weekday windows, date exceptions, a buffer, fixed events, other planned sessions, and a minimum 15-minute suggested session. It reports a hard no-slot issue and an overridable deadline warning. The default example plan is weekdays 09:00–17:00; it is not yet editable or persisted.

The engine is not connected to a user-facing Apply action. Availability settings, preview UI, transactional history/restoration, dependencies, sequences, and the other reschedule operations remain.
