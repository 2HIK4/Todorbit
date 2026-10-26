# Widget refinements and optional support

2026-10-27. Implementation continues the interrupted
`feature/ui-ux-pro-max-polish` work on `feature/widget-refinements-support`.

## Recovery and design reference

Preserved all four tracked interrupted changes: select trigger focus, matching
custom-background foreground contrast, and their two regression test files.
The review capture script/images stay ignored under `build/ui-ux-review/`.
The original diff is retained there as `interrupted-safety.patch`.

UI UX Pro Max is already discovered by this Codex session at
`C:/Users/User/.agents/skills/ui-ux-pro-max/SKILL.md`. No reinstall, global CLI,
new dependency or restart was needed. Node 24.15.0, npm 12.2.0 and Python 3.14.5
were available. Its Python design-system generator and actual CSV searches ran:

- `productivity dashboard desktop --design-system -p Todorbit`: Flat Design,
  semantic contrast, simple hover and restrained effects. Its marketing layout,
  teal/orange palette and web font imports were rejected as unsuitable here.
- `ThemeData --stack flutter` and `theme accessibility --stack flutter`:
  centralized theme access, both modes and native semantics.
- `keyboard focus visible --domain ux`: visible focus and unobscured controls.
- `readable --domain typography`: accessible sans-serif text and hierarchy;
  retain existing fonts and native Segoe UI rather than introducing downloads.
  The initial `readability hierarchy` query had no match; the narrower retry did.
- `scroll affordance --domain ux` returned web anchor scrolling/input styling;
  it does not establish a native scroll-fade recommendation. The fade is an
  explicit owner request implemented using Todorbit's existing theme roles.

The compact Fluent-inspired lavender identity, 4/8 spacing rhythm, rounded
shared controls and user palette settings remain the design baseline.

## Implemented findings

| Component | Cause and resulting change |
| --- | --- |
| Calendar widget | Two modes fragmented visual quality/agenda capacity. One rounded month grid and separate agenda replace them. Unknown/old mode fields are ignored on load; unrelated settings survive. |
| Calendar sizing | Grid consumed extra height. Width-derived cell heights are bounded; 4/5/6 weeks share geometry. Tall/wide widgets retain the grid above a larger agenda. |
| Selected-day agenda | Paging arrows obscured continuous content. All projected items remain available through bounded row scrolling, a fixed date heading and subtle scroll cue. Wheel input outside the agenda does not scroll it. Item type, time, cancellation and detail inspection remain. |
| Widget geometry | Manual alignment and logical rounding made exact edges difficult. Nearby visible companion bounds provide 10 physical-pixel snapping with 6-pixel release hysteresis. Only active edges/moving host change. Same-DPI physical dimensions survive restart; other DPIs use logical dimensions. |
| Widget menu | Removed redundant Quick Add from Flutter widget controls and the native tray. Input bar, hotkeys and compatible IPC remain. |
| Settings scrolling | Shared pointer-transparent 18px bottom fade appears only with content below in Settings, theme and widget editors. Fixed Apply/Cancel actions stay separate. |
| Shared select | Trigger-owned focus node now drives the themed border before opening and restores focus after dismissal. Existing bounded/anchored menus remain. |
| Custom colors | Accent/error overrides previously retained seed-derived foregrounds. Black/white foreground selection now guarantees at least 4.5:1 for opaque custom backgrounds. |
| Header/support | Replaces the Notifications shortcut with Support Todorbit; Notifications remains in Settings. Optional scrollable popup has one PayPal action, error recovery and normal modal dismissal. |
| Discoverability | Four-second optional pulse, static with reduced motion, claimed once through the repository into device/profile-local `support-introduction.json`. No automatic popup or settings-transfer field. Packaging rejects this local receipt. |

The audit reuses the prior cross-app review in `WIDGET_REDESIGN_UI_AUDIT.md` and
`CALENDAR_UI_AUDIT.md`: Tasks/editor, Calendar/events, Habits/Goals, shared forms,
menus/color picker/tooltips, settings/appearance, backup/restore and updates.
This pass changes shared causes rather than replacing stable feature layouts.
Unchanged feature tests remain part of the final CI gate.

## Official support identity

The only official destination is **https://paypal.me/2hussam4**, centralized in
`lib/features/support/support_button.dart`. Neither themes, backups, local
preferences nor remote configuration supplies it. The Windows resource channel
opens the default browser and reports launch failure. No in-app payment data,
tracking, account, SDK or third-party payment platform is added.

Forks can change public source. Official integrity depends on maintainer-owned
`2HIK4/Todorbit`, the reviewed release commit, Windows CI, SHA-256 verification
and the established release pipeline. Existing packages remain unsigned;
checksums are not publisher signatures. No repository protection is weakened.

## Verification

- Focused Flutter regression: **42 passed** across support, fade, widget editor,
  settings, palettes and application theme. Separate select/config regressions
  passed earlier. Initial support-test compile error was corrected and rerun.
- Targeted Flutter MCP analysis: no errors. Live isolated debug hot reload passes.
- Native Release build: zero warnings/errors. Current-source `--self-test` and
  `--lifecycle-self-test` pass: simultaneous Explorer child windows, independent
  visibility/reload/restart and live-preview rollback. An early harness pointed
  to an older RID output; it was corrected to the current build output and rerun.
- Fresh native offscreen renders reviewed at minimum and tall sizes, light/dark,
  plus generated 100/125/150/200% raster scales. These are synthetic fixtures.
- Live debug screenshots inspected the support popup in both themes and light
  Habits, Goals, Backups and Software Updates. The app reported no runtime errors
  and the isolated debug process closed normally. Its version metadata predates
  the final version bump; final built binaries separately report 1.0.16+17.
- Final local full analysis passes. Initial CI stopped on two style infos omitted
  by the targeted error-only diagnostics; the mechanical corrections are in
  `6e3b64b`. Exact-source final CI passes **340 tests, one opt-in skip**, analysis,
  build, native test and packaging gates. No extra local full suite was run.
- Physical narrow-window/DPI, mouse-wheel/drag snapping feel, Win+D, Explorer
  restart, multiple monitors, screen reader and registered installer execution
  remain **UNVERIFIED**. Automated geometry/lifecycle checks do not prove them.

Final exact-commit build, publication and updater receipts are recorded in
`TODORBIT_1_0_16_PUBLICATION.md`.
