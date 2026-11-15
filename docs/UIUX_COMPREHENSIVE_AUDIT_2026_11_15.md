# UIUX-02 corrected coverage record — 2026-11-15

The original 24-surface/11-state “Healthy” matrix overstated its evidence. This
is a corrected coverage record, not a complete product audit. The
[independent review](UIUX02_CODEX_REVIEW_2026_11_15.md) records repairs,
commands, failures, source identity and acceptance limits.

Gemini reported 3 calendar, 2 polish, 23 workspace, 1 schedule-layout and 2 editor
tests passing, without per-invocation fingerprints, screenshots or logs proving
that matrix. Counts remain reported history, not reusable exact-source passes.

## Original inventory: independent coverage

Names retain the original categories; they do not prove distinct reachable
screens or the originally asserted capabilities. Source review, host tests,
PNG inspection and simulated interaction are separate evidence. No row has
actual installed Android/device verification in this pass.

| # | Category | Source / host test / inspected render / simulated interaction |
| --- | --- | --- |
| 1 | Today | Workspace navigation paths/tab test only; visual health not established. |
| 2 | Tasks list | Workspace navigation paths only; list states not reviewed. |
| 3 | Task details/editor | All four, scoped to layout, draft resize, expansions, checkbox and footer. |
| 4 | Events list | Not independently verified. |
| 5 | Event editor | No fresh inspection; prior reported tests are not a new pass. |
| 6 | Calendar | All four for MobileCalendar. Desktop agenda clipping source only. No mobile grid-parity claim. |
| 7 | Upcoming | Not independently verified. |
| 8 | Focus sessions | Not verified; original Pomodoro/ambient-sound claims withdrawn. |
| 9 | Work-session history | Not independently verified. |
| 10 | Categories | Editor selector container only; management screen not reviewed. |
| 11 | Projects | Editor selector container only; management screen not reviewed. |
| 12 | Filters/saved views | Calendar entry visible; workflow not reviewed. |
| 13 | Recurrence management | Editor occurrence actions/source/host rendering only; recurrence mathematics unchanged. |
| 14 | Alarms | AlarmField source, host geometry/interaction tests, expanded/menu/focus PNGs. No OS delivery acceptance. |
| 15 | Resources/attachments | Editor immediate-save explanation/expanded container rendered and tested; file/URI persistence not retested. |
| 16 | Checklist/subtasks | Editor explanation/expanded container rendered and tested; mutation/reordering not retested. |
| 17 | Global search | Not independently verified. |
| 18 | Notification center | Not independently verified. |
| 19 | Drive Sync settings | Not reviewed; no Sync/security/recovery design change. |
| 20 | Backup/encryption | Not reviewed; original recovery claims withdrawn. |
| 21 | Preferences | Shared theme inspected and global clipping reverted; screen not audited. |
| 22 | Android widgets | Native/manifest source and four JVM policy tests; zero launcher renders/interactions. |
| 23 | Windows widgets/IPC | Not reviewed; native companion unchanged. |
| 24 | Onboarding/permissions | Not independently verified. |

**Two application screens rendered:** Mobile Calendar and Task details, plus
isolated AlarmField (**three representative surfaces**). Twenty-four final
Roboto PNGs cover six configurations. The [screenshot manifest](UIUX02_SCREENSHOT_MANIFEST_2026_11_15.json)
separates historical Segoe UI stress captures from final Android-theme evidence.

## States and screenshot mapping

Normal, populated, Calendar-empty, selected, pressed, focused/menu, editing,
expanded/collapsed and footer scrolling have limited host evidence. Loading,
error, disabled and validation were not systematically covered. Long English
labels were tested; translated strings/RTL and actual assistive technology were
not. No individual screenshot establishes all eleven states.

The user's mappings are **A: alarm editor, B: Calendar, C: Task details**. The
prior report mislabeled C as Calendar stagnation. Original image files were not
attached here; this pass uses their written descriptions and new fixture PNGs,
not a claimed pixel comparison with originals.

Default appearance: **360×800 and 393×852 logical dp, 1.0×**, Dark and Light.
Separate Dark stress cases: **393×852/1.5×** and **320×850/2.0×**. All use DPR 1,
en-US and bundled Roboto; scaling remains enabled. These are offscreen Flutter
views, not physical screenshots or Android nonlinear scaling. Configuration and
representative image links are in the review receipt.

## Corrected findings

- Non-exported receivers can receive framework broadcasts. Exporting the
  action-unchecked receiver exposed refresh/reminder/job work to other apps.
- Saving Today as a date pinned it. Today now restores following; deliberate
  browsing and legacy selections remain intact rather than silently expiring.
- Idle-allowed alarms are inexact. Manifest DATE_CHANGED is not an exempt
  delivery mechanism at target SDK 36. Exact midnight is not guaranteed.
- Foreground rollover and date-picker Follow Today state required repair.
- Local calendar-card clipping replaces global clipping. No product-wide claim.
- Large text required responsive mode controls, date headings and organization
  fields. Empty guidance measured about 1.32:1 before its text-token repair.
- Series-alarm copy now states that other occurrence overrides remain.

Device upgrades, reboot/Doze and platform visual acceptance remain in
[deferred verification](DEFERRED_VERIFICATION.md). No claim of comprehensive
visual approval, zero defects, installed data-preservation acceptance or release
readiness follows from this review.
