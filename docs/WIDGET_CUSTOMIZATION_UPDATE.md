# Widget customization and Calendar Widget — development record

Branch: `feature/widget-customization-calendar`, based on main `3d499fb`.
Scope: requested update/download presentation, Backups & Cloud, cancelled-event
readability, configurable Tasks Widget and separate Calendar Widget. No general
UI audit, version/tag/release publication, Cloud configuration or personal-profile
changes are authorized.

## Implemented behavior

| Area | Result |
| --- | --- |
| Updates | Reusable IEC sizes with a common unit, bounded decimals and unknown/invalid handling; accurate clamped progress; full selectable Markdown behind collapsed Details. Removed the entity-encoded, truncated summary. Update download/verification/install services are unchanged. |
| Backups & Cloud | Compact sections and actions, disclosures for retention/security/settings explanations. Passphrase and destructive replacement confirmations remain intact. No OAuth/encryption/cloud-format changes. |
| Cancelled events | Stronger title contrast and background, retaining strikethrough and cancelled status in month/day/week presentations. |
| Tasks Widget | Independent title/Open visibility; collapsing header; all four views can be hidden/shown, positioned on any side, and displayed as text/icons/both. Context menus retain all views and management actions. |
| Appearance | Typed per-widget, versioned JSON; theme-relative defaults; independent shell, panel, input, header, navigation/button, cell, agenda and date-indicator surfaces; color/opacity/border/radius, text scale, reset and optional text backplates. No content-wide opacity. |
| Calendar Widget | Monthly grid, today and selection, previous/next/Today, indicators and scrolling selected-date agenda. Planned tasks, sessions and fixed events remain distinct. Existing calendar filtering/week start and native recurrence matching are reused. Moved/cancelled occurrences retain their date/title; agenda instants sort chronologically. Task/session items open their task; events are read-only. |
| Lifecycle | Two Explorer child HWNDs inside one existing companion/IPC/startup identity. Independent visibility and geometry; deterministic legacy task migration; calendar starts disabled. Non-overlapping initial placement where display space permits. |
| Settings/routing | Separate overview entries/editors. Apply saves only the selected draft; confirmed Apply to All copies shared header visibility, text/readability and shell/header/content appearance. Geometry, enabled state, layout lock, task navigation/input and calendar-specific surfaces stay independent. Cancel writes nothing. Failed second saves restore the first configuration. External Edit This Widget requests select the correct editor; dirty drafts require discard confirmation when switching. |
| First launch | Show/reload/view commands detach when they can become the persistent companion. One-shot commands still report exit failures. Real isolated-profile integration verifies that first launch and Apply reload finish instead of leaving Settings busy until companion exit. |

The new configuration files are `widget-tasks-configuration.json` and
`widget-calendar-configuration.json` in the active existing profile. Task geometry,
view and startup preference remain in `widget-settings.json`; Calendar geometry
uses `calendar-widget-settings.json`. Existing `%APPDATA%\TodoPilot`, legacy and
portable profile routing, installer identity, SQLite v21, OAuth and encryption
are unchanged. New widget customization is device-local; shared theme colors
remain portable. Ordinary app updates retain these profile files.

Launch/configure in **Settings > Widget**, or right-click **Edit This Widget**.
No saved files are changed by the in-editor preview. The selected editor offers
Apply, confirmed Apply to All Widgets, Cancel and Reset customization.

Typography investigation found a separate native GDI+ alpha-composited drawing
path alongside Flutter's renderer, with existing PerMonitorV2 awareness and
grayscale antialiasing. The layered surface now uses explicit logical pixel font
sizes and regular Segoe UI Semibold rather than synthetic bold. The temporary
WinForms input retains native point/DPI font scaling. No blur/shadow or font-glyph
icon workaround is used. A ClearType switch was deliberately avoided: Microsoft's
[layer documentation](https://learn.microsoft.com/en-us/windows/win32/api/d2d1/ne-d2d1-d2d1_layer_options)
explains its dependency on an opaque background. Offscreen scaling is separate
from physical display verification.

Design references applied from the resolved Apple skill: `layout.md` > Visual
hierarchy (progressive disclosure), `accessibility.md` > Vision/Mobility (contrast,
labels/input alternatives), `typography.md` (legibility), `icons.md` > Best
practices (consistent vector weight), plus relevant desktop/settings/widgets/
menus/color and cross-platform guidance. These are translated to Todorbit's
existing Windows styling and controls.

## Verification and limits

Evidence stays under ignored `.buildlog/widget-customization/`.

- The final full-source run completed **304 cases: 303 passed, one opt-in case
  skipped**, zero JSON error events, **379.966 seconds**. Evidence:
  `full-tests-delivery.jsonl`. The skipped real-native launch case passed
  separately on fresh isolated profiles, including the final packaged companion
  (`packaged-launch-integration.log`). The earlier 301-test run also passed.
- Complete analysis is clean (`analysis-final-source.log`, 16.7 seconds);
  final Windows Release passes (`windows-final.log`, 33.7 seconds), followed by
  the native CMake Release target for final accessibility/cursor refinements
  (`native-final-publish.log`) and repeated packaged native checks.
  The bundle retains development version 1.0.13+14; no version/tag/release change.
- Focused routing/editor tests cover correct external selection, no duplicate
  editor, dirty-draft cancellation/discard, per-widget Apply, current visibility,
  compatible Apply to All and rollback after an injected second-save failure.
- An opt-in real-companion Flutter test passes on a fresh, explicitly isolated
  profile (`native-service-launch-final.log`). It is skipped in ordinary suites
  unless `TODORBIT_NATIVE_SERVICE_EXE` is supplied; it is not a mocked launch.
- Native Release/self-test passes, including compact layout modes, hidden
  headers/navigation, larger text, independent opacity, custom light shell text,
  recurrence exceptions, calendar dates and 100/125/150/200% offscreen scaling.
- Final **packaged** self-test, two-HWND lifecycle and offscreen render all pass
  (`packaged-summary.json` and `packaged-*.log`). The Windows Run registry
  fingerprint is identical before/after these checks. Personal installed process,
  profile and registration were not operated on. Synthetic profiles are retained
  under the ignored run; native lifecycle temporary profiles are cleaned up.
- Actual two-HWND native lifecycle passes with disposable data: simultaneous
  display, independent hide/show, configuration reload and restart restoration.
- Isolated debug Flutter MCP hot restart/reload passes with no runtime errors.
  Native runner activation from separate processes selected Tasks then Calendar
  in the already running app, with exactly one editor visible each time.
  The isolated debug app was closed gracefully after verification; only the
  pre-existing personal widget process remained. Live results are summarized in
  `live-mcp-summary.json`.
- Rendered evidence: `settings-editor.png` and `renders-final/` (synthetic native
  fixtures, light/dark, compact layouts and scaling). These are offscreen renders,
  **not** physical desktop screenshots. Initial pre-fix images are historical.

Physical keyboard/mouse/dragging, native text-input focus, screen-reader behavior,
actual Windows scaling, Win+D and Explorer-restart recovery remain **unverified**.
The existing manual checklist applies to both widgets. No Sandbox/VM is required.
No new registered installer acceptance, release publication or general UI audit
is claimed. Event editing from the calendar agenda is intentionally unavailable.

## Interruption checkpoint — 2026-10-26

VS Code was force-closed during integration verification. All 16 tracked edits
and 14 new source/test files survived, with no temporary source files or whitespace
errors. No development app, native test or Flutter test process remained running.
The personal installed widget was running and was left untouched.

Present implementation: IEC download formatter; collapsed full Markdown release
notes; compact backup settings disclosures; cancelled-event background adjustment;
versioned per-widget appearance/configuration; task header/navigation controls;
second calendar HWND in the existing companion process; calendar projection;
Apply/Apply to All/Cancel editor; widget-specific activation routing; native
accessibility actions; offscreen render and regression fixtures.

Surviving evidence under ignored `.buildlog/widget-customization/`:

- Native Release and expanded `--self-test` passed; error log empty.
- Windows Release build completed in the previous tool result (197.4 seconds).
- Focused model/editor/settings/Markdown/backup tests passed in prior runs.
- Full-suite JSON contains 68 completed tests, no error events and no final
  completion event. It was interrupted during database process-death coverage;
  this is **not** a complete suite pass.
- Offscreen native and Flutter editor images survived. Earlier calendar images
  precede the corrected Today/weekday spacing and must be regenerated.
- Debug build/live MCP connection did not complete. Physical input, DPI,
  Explorer/Win+D and actual desktop appearance remain unverified.

Remaining **at that historical checkpoint**: review configuration/lifecycle edge cases, complete rendering and
targeted checks, rerun interrupted integration verification, update this record
and project progress/architecture notes, review the final diff and commit locally.

Design skill: `C:/Users/User/.agents/skills/apple-design/SKILL.md`, applying
accessibility, layout, typography, color, desktop, widgets, settings, menus and
icons references plus cross-platform translation. Todorbit keeps its existing
Windows conventions and light/dark palette; no Liquid Glass is introduced.
