# Todorbit 1.0.19-beta.19 — Calendar data safety and date refresh

Experimental Windows and Android candidate, build 42, SQLite schema 28.

- Calendar Undo/Redo changes the intended date/time while preserving later task
  and event edits, deadlines and work-session outcomes.
- Moving a continuation of an overnight or multi-day event keeps its original
  start offset and duration. Resize handles appear at actual event boundaries.
- Midnight resizing preserves the 15-minute minimum and supports an exact
  midnight end time.
- Date rollover reloads Today events and recurring tasks. Disposed controllers
  cannot rearm the midnight timer.
- Failed calendar changes show a dismissible error; failed Undo/Redo entries are
  retained. Successful edit notifications still dismiss after four seconds.

Windows Google Drive Sync remains intentionally disabled. Android platform
Google authentication retains its existing configuration and acceptance limits.
Standard/Private Sync, encryption/recovery, local backups, profiles and database
schema are unchanged. Windows packages remain unsigned. Stable is unaffected.

Production Android uses its touch calendar/agenda; desktop timeline gestures
are Windows features. Physical device, native input/DPI and installer acceptance
must be reported separately from automated checks. This file is candidate notes,
not a publication receipt or a claim that release gates passed.
