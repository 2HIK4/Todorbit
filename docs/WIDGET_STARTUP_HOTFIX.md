# Widget startup and appearance hotfix

Candidate **1.0.18+19**, branch `fix/widget-startup-and-appearance`, based on
`5c55b55` (published v1.0.17 source `cae2b4b`). No schema or profile-format bump.

## Findings and changes

- **Calendar shown as Off / temporary closure persisted:** the native Close Widget
  menu called `Hide()`, which saved `enabled=false`. That file lives outside
  the installed bundle and portable replacement path, so the disabled value
  survived updates. The tray Exit widgets command already avoided configuration
  writes. Close Widget now hides only for the session; explicit Settings toggles
  and tray Show/hide retain their persistent semantics. Session closure also
  suppresses Explorer recovery until an explicit restore/show command.
- **Main app reopening did not restore widgets:** Release startup only synchronized
  the sign-in registration and optionally launched a reminder-only companion.
  It now sends the existing profile-scoped restore command. The same command
  reconciles enabled widgets in a new or already-running companion, without
  forcing Tasks on or duplicating Calendar HWNDs. Reminder-only startup shows
  neither widget; Windows sign-in continues to restore enabled widgets without
  opening Flutter. Missing enabled fields default Tasks on / Calendar off in
  both readers; explicitly saved booleans always win and loading does not rewrite.
- **Navigation foreground:** automatic text first followed opaque accent, then a
  second rule substituted black/white against a composed translucent background.
  The new opacity sweep regression fails with the old code (two foreground
  changes). Selected text now uses one strongest-contrast black/white decision
  against the composed surface over the stable theme background. Explicit text
  colors/alpha bypass it; wallpaper is never sampled. Existing text protection,
  ordered previews, 70 ms coalescing and gesture history remain in place.
- **Calendar square:** this was the planned-task marker, not today or event count.
  Only its grid rendering becomes a filled background-derived darker circle with
  a subtle contrast edge, inset from the cell. Agenda task squares and the session
  symbol remain meaningful. Event counts remain 0 none, 1-3 dots, 4+ a line;
  today outlines and date-selection styling remain intact.

An older saved false cannot be classified as accidental versus intentional.
The hotfix preserves it; re-enable the affected widget once in Settings if needed.
No updater reset was added or inferred. Installed updater replacement remains
outside the profile; portable replacement retains the exact location-derived
profile path. Tests use disposable data only.

## Regression coverage

- Flutter production-shaped settings: both widgets' four enabled combinations,
  reopening independent stores, missing-field migration, immutable load bytes,
  geometry/layout/opacity and existing additive defaults.
- Native actual-HWND lifecycle: simultaneous widgets, temporary close without
  writes, restore/repeated restore, explicit disabling, companion/background
  startup and restart, unchanged host identity and active-editor preservation.
  Existing mutex/pipe tests plus opt-in real process
  forwarding/restart detect a second long-lived companion.
- Native 0-100% opacity sweeps for shell/navigation/selection, both themes and
  custom selection colors: deterministic output, at most one transition,
  readable automatic contrast, explicit HEX colors and independent text alpha.
- Native Calendar geometry, event counts, task-circle padding, theme-aware color
  derivation, 4/5/6-week layouts and 100/125/150/200% offscreen fixtures.
- Portable update harness hashes both enabled configuration files through update
  and rollback, requires one companion after repeated launch, and cleans up the
  restarted companion. Single-instance fixtures suppress sign-in registration
  and clean up their two isolated companions.
- Existing full suite covers presets, history/gesture coalescing, navigation,
  reminders, local/Drive backup round trips and migrations.

## Acceptance boundary

Actual-HWND lifecycle and offscreen render checks are automated Windows evidence.
Physical mouse dragging, Explorer/Win+D appearance, Windows login, multi-monitor
movement, physical 100/125/150/200% display scaling and registered installer
execution require separate target-system acceptance. No setup is executed on
the owner's account. Real-account Google OAuth is not repeated for this hotfix.
Release/build/updater results are recorded with the publication or candidate
checkpoint; prior release receipts are not current-test evidence.
