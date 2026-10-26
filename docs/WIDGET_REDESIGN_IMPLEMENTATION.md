# Widget redesign and live customization

Date: 2026-10-26. Branch: `feature/widget-redesign-live-preview`.
Baseline: `ce535e4` (main, following the v1.0.14 pre-release).

## Architecture and implementation

The persistent widgets remain native Explorer child windows. Flutter owns the
settings editor. Calendar and Tasks retain independent configuration, visibility
and geometry in one companion with the established profile pipe, startup entry,
data paths and installer identity. No schema, recurrence or scheduling migration
is introduced. No release, upload, cloud configuration or personal install change
is part of this work.

The dependency order was shared UI grouping, native calendar/layout, native input
and menu behavior, draft IPC/lifecycle, application audit, and integrated checks.
The primary risks were accidentally persisting a preview, conflicting native
menu edits, cramped seven-column calendars, and shell/DPI/focus regressions.

## A. Implementation summary

- Shared spacing and hierarchy connect section headings to their controls.
  Color fields show a swatch and open the reusable validated picker. Sliders
  display percentages or pixels, with meaningful accessibility values.
- Tasks gains balanced empty content, larger completion hit areas, clearer hover
  and pressed behavior, and an adaptive icon rail for side navigation below
  340 logical pixels. Saved navigation preferences remain intact.
- Native ordinary labels no longer acquire opaque rectangles. Optional glyph
  shadows improve readability while preserving configured surface transparency.

## B. Calendar presentation

Settings > Widget > Configure calendar widget > Calendar presentation offers
**Compact Calendar + Agenda** and **Full Month Grid**. The optional version-1
`calendarPresentation` field defaults older files to `compactAgenda`.

Compact limits and centers the date grid instead of spreading numbers across a
wide background. Full Month separates days, prioritizes item titles in narrow
cells, and adds previews and `+N more` as capacity increases. Both modes retain a
selected-day agenda; wide windows place it beside the grid. Navigation arrows
and wheel scrolling reveal all agenda entries. Clicking an agenda row opens
native full text/details, with an optional Open task action. Event editing stays
unavailable. Detail windows close with Calendar and when privacy locks.

Both modes share week-start/content preferences and the existing native
repository projection/recurrence matcher. Planned tasks, sessions, events and
cancelled occurrences retain their distinct meanings. Minimum sizes remain
300x360 Calendar and 260x230 Tasks at normal text size, increasing with text
scale. Painting, hit-testing and accessibility use common calendar geometry.

## C. Live customization lifecycle

- Changes update the enabled desktop widget after a 70 ms coalescing delay.
  The Windows method channel sends directly to the existing profile pipe;
  preview does not launch a companion or write preference files.
- Session UUIDs and increasing sequence numbers reject stale updates.
  Two-second heartbeat messages renew an eight-second lease without repainting
  unchanged content or rereading settings. App loss expires the draft to disk's
  saved settings. A newer heartbeat can recover a timed-out connection; explicit
  cancellation remains terminal. A companion restart accepts the next heartbeat.
- Apply saves safely, advances the committed baseline, and keeps editing open.
  Cancel discards only changes since the latest successful Apply and closes.
- Close and Escape prompt **Save Changes / Discard Changes / Continue Editing**
  only for semantic changes. Confirmation content scrolls in short windows.
- Confirmed Apply to All copies shared title/Open visibility, text/readability
  and shell/header/content appearance. It preserves identities, enabled states,
  geometry, layout locks, task controls, Calendar mode and calendar surfaces.
- The editor watches atomic configuration changes. Three-way reconciliation
  preserves unrelated draft/menu changes and gives a newer saved edit priority
  on the same property. Native context commands save only their selected field,
  never the displayed draft.
- Visibility changes read the latest saved configuration before altering only
  the enabled flag. During saving, form input/focus is unavailable so ignored
  edits cannot leave dropdowns or color fields displaying unsaved values.
- A failed save leaves the editor and draft open with an error. A second-widget
  failure restores the first file. Each file is atomic; two-file Apply to All is
  not crash-atomic across sudden process/power loss.

## D. Interaction improvements

Unlocked unoccupied backgrounds and the header/grip allow movement. Interactive
hit regions, scrolling and resize edges retain priority. The grip appears on
hover; move/resize cursors match the operation. Press and release must match
before an action fires. Lock prevents movement, resizing and centering.

Context menus expose a native check column for persisted title, Open button,
lock, opacity and task-view choices. Commands are grouped with separators.
Rounded themed tooltips wait 600 ms, scale from the widget monitor, clamp to the
screen, and use nonactivating/click-through popup windows. Leaving or interacting
dismisses them. Existing shell attachment/startup paths remain in use.

## E. Application-wide audit

| Location | Original problem | Severity | Implemented fix | Verification |
| --- | --- | --- | --- | --- |
| Calendar HWND | Continuous oversized grid, weak cell/content hierarchy, no month previews. | High | Two responsive modes, separated days, capacity/overflow and complete native agenda details. | Mode/date/projection/overflow/layout self-tests; dark/light offscreen review. |
| Widget editor / IPC | Apply closed the dialog and only a schematic local preview existed. | High | Transient actual-widget previews, Apply baseline, rollback, dirty close choices and leased recovery. | Flutter lifecycle/continuous-drag tests; actual two-HWND routing and saved-file checks. |
| Native menus | Check states were stored but the check column was suppressed. | Medium | Native check margin and persisted field checks; save only the selected property. | Constructed real-menu checks and preview-preservation self-test. |
| Movement and input | Useful drag regions were restricted to thin margins. | High | Unoccupied background/header/grip hit regions, protected controls, matched press/release, lock. | Hit geometry, lock and input-region self-tests; physical dragging still unverified. |
| Transparent labels | Per-label opaque backplates created visual clutter. | Medium | Optional glyph shadows with unchanged surface alpha. | Transparent-label pixel self-test and offscreen inspection. |
| Tooltips | Immediate, default-looking native surface conflicted with themes. | Medium | 600 ms delayed rounded theme/DPI-aware nonactivating popup. | Dark/light 100/125/150/200-percent offscreen tests and screen-clamp tests; physical placement unverified. |

The [findings table and coverage](WIDGET_REDESIGN_UI_AUDIT.md) document concrete
causes, severities, fixes and evidence for shared sections, tooltips, select
keyboard traversal, theme fields/colors, prompt lifetimes, hotkeys, task
preferences, notifications, privacy/lock UI and backup explanations.

Integration additionally caught a section expansion bool colliding with nested
scroll offsets and a backup action column overflowing at narrow widths. Section
content now owns an isolated PageStorage bucket. Backup controls/history share
one scroll region, and embedded panels avoid duplicated horizontal padding.
Existing dark/light backup tests reproduce and verify these paths.

The source audit also covered workspace/tasks, task detail/editor, calendar
Day/Week/Month, event/session forms, projects/categories, habits/goals/reports,
templates, focus tracking, archive/trash, search, updates and settings transfer.
Unchanged screens retain their existing regressions; source review alone is
not populated visual acceptance of every screen.

## F. Verification

Evidence files remain ignored under `.buildlog/widget-redesign/`.

| Check | Result |
| --- | --- |
| Changed Dart formatting | 23 files checked; no formatting changes required. |
| Full serial Flutter integration | 328 cases: 327 passed, one opt-in native launch skipped; zero error events, 374.505 seconds. `full-tests-verified.jsonl`. |
| Subsequent final editor regressions | 11/11 passed, including continuous slider input before release, reconnect feedback, external visibility merge and save/close/rollback. `live-drag-verified.log`. These verify the final preview cadence/reconnection refinements after the full run. |
| Opt-in packaged first launch | 1/1 passed separately on a new guarded disposable profile; first calendar launch/reload returns while companion remains alive. `native-launch-integration.log`. |
| Final full analysis | No issues, 17.2 seconds; `analysis-final.log`. |
| Native Release | Zero warnings/errors; expanded self-test passed, including timeout recovery and cancelled-session rejection. |
| Windows Release | Passed, 102.6 seconds on the final preview source; `windows-release-final.log`. |
| Bundled native checks | Self-test and lifecycle exit 0; `packaged-self-test.*` and `packaged-lifecycle.*`. Lifecycle includes actual two-HWND target-only preview, unchanged saved bytes, rollback, independent visibility and restart. |
| Offscreen visual review | Dark/light Tasks, both calendar modes at minimum/medium/wide/tall, transparent labels and rounded tooltips inspected. `renders-final/`. |
| Live isolated debug | Debug build passed (150.8 s). Flutter MCP verified mode/title preview without saved writes, Apply stays open, Cancel/reopen keep the saved mode, dirty Close/Continue, successful hot reload and no runtime errors. Existing companion PID remained unchanged during editing, survived Flutter exit, and restarted with saved preferences. `live-summary.json`, `live-editor-dark.png`, `live-unsaved-dialog-dark.png`. Test processes were closed cleanly. |

```powershell
dart format <changed Dart files>
flutter analyze --no-pub
flutter test --no-pub --concurrency=1 --reporter json
dotnet build experiments/widget-shell-probe/widget-shell-probe.csproj -c Release --no-restore
TodorbitWidget.exe --self-test
TodorbitWidget.exe --lifecycle-self-test
TodorbitWidget.exe --capture-widgets <isolated-output-directory>
flutter build windows --release --no-pub
```

Focused tests cover migration/round trips, independent persistence, mode defaults,
semantic dirty state, concurrent merges, correct preview targeting, Apply/Cancel,
all close choices, confirmed shared Apply and failed-save rollback. Native tests
cover ordered/expired leases, cancellation tombstones, menu checks, hit targets,
calendar selection/grouping/capacity/overflow and layout at multiple sizes.

Initial integration found backup overflow/storage failures, then the new
360x480/1.5x editor check found a confirmation overflow. These were corrected at
their shared causes. An intermediate command also named a nonexistent
`test/backup_dialog_test.dart`; the corrected command uses the actual
`test/cloud/backups_cloud_page_test.dart`. No assertions were removed or weakened.

Offscreen images include both calendar modes/dark/light at minimum, medium,
wide and tall sizes, Tasks navigation arrangements, transparent surfaces and
tooltips at 100/125/150/200 percent render scales. Offscreen scaling is not
physical Windows DPI acceptance. Actual native lifecycle checks use disposable
profiles and two real HWNDs, including target-only preview and rollback.

## G. Remaining verification limits

Physical mouse dragging/resizing, keyboard-input focus, Win+D, Explorer restart,
multi-monitor movement, screen-reader interaction, and physical 100/125/150/200
percent Windows scaling require the [manual checklist](windows-widget.md).
Native computer-control APIs are unavailable in this session. Wallpaper contrast
is inherently variable; the user can keep configured surfaces and text shadows.
Windows 10 compatibility is retained in the APIs/architecture but was not tested
on a separate Windows 10 machine. No registered installer or sign-in test ran.

## H. Repository state and release readiness

Changes are committed locally on the feature branch after final diff review.
No tag, push, GitHub release or public asset update is authorized by this task.
Release readiness still depends on the physical Windows acceptance above.
