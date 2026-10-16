# Scheduling and Smart Reschedule

Keep scheduled dates, deadlines, planned sessions, actual time, and fixed events separate. A deterministic engine will read availability, exceptions, durations, buffers, locks, dependencies, events, and deadlines. Operations include move/shift/push/pull/reorder/swap/repack/split and sequence scheduling. Return a preview of hard conflicts and overridable warnings before any transactional apply. Record before/after history and preserve later manual edits during restore by default.

Test no-slot explanations, protected events, deadline and dependency warnings, multi-selection atomicity, undo, and restoration after manual edits.

## Current implementation

Fixed events and planned work sessions are persisted independently. Session outcomes are explicit; passage of time only creates “Late start” or “Needs confirmation” indicators. The automatic scheduling engine, preview, availability configuration, conflict resolution, and scheduling history are not yet implemented.
