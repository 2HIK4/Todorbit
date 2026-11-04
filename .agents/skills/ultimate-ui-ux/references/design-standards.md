# Design and experience standards

Use for the affected interface; this is not an instruction to redesign an app.
Existing product tokens and Windows Fluent/Android Material conventions take
priority over generic styling or supplemental Apple HIG advice.

## UX Necessity Review

For every screen, major component or workflow created/evaluated, ask:

1. Is this element necessary?
2. Does the user need this information right now?
3. Can the app safely handle this automatically?
4. Can two redundant steps be combined?
5. Can the feature work with fewer decisions?
6. Is the terminology understandable to an ordinary user?
7. Can advanced details be hidden until needed?
8. Does the screen prioritize the user's actual goal?
9. Is there a simpler design preserving all necessary functionality?
10. Would removing or simplifying this element improve the experience?

Record the outcome proportionally: a short rationale suffices for a local fix.
Prefer sensible defaults, contextual help, one clear primary action and
progressive disclosure. Preserve legitimate advanced controls and safety
acknowledgments. Automate only where supported by actual domain/platform rules;
never silently complete/reschedule tasks, choose conflicts, delete data or change
encryption. Avoid adding explanatory prose when clearer controls solve the cause.

## Hierarchy and tokens

Inspect the existing design system and shared consumers before local styling.

| Role | Treatment and inspection |
| --- | --- |
| Page title | Highest relevant heading; name the current destination, not a paragraph |
| Section/subsection | Consistent heading tokens/semantic headers; spacing groups related controls |
| Field label | Persistent, concise, associated with the control; distinct from entered value |
| Primary content | Readable body/item role; strong enough for the screen's main job |
| Supporting description | Secondary semantic foreground, shorter measure and lower emphasis |
| Metadata/caption | Quieter size/weight, still legible and accessible; full identity available |
| Disabled text | Explain unavailable capability where needed; do not rely on faintness alone |
| Error/warning | Actionable text and icon/state in addition to color; preserve user input |

Do not make all dark-mode text bright white, or solve hierarchy by enlarging or
accenting everything. Measure actual composited contrast after lowering emphasis.
Reuse typography, spacing, surface/elevation, border/radius, icon, control, dialog,
focus, status and motion tokens. Introduce a token only for a stable shared role.
Avoid redundant nested cards, arbitrary offsets and decorative abstractions.
Compare normal, hovered, focused, selected, pressed, disabled and pending states.

Todorbit: `app_theme.dart` owns semantic text and palette-derived surfaces;
`AppSpacing`, `SettingsSection`, `SettingsHelperText`, `StatusNotice`, anchored
selectors and dialog action bars already exist. Do not replace the lavender
identity or overwrite saved custom palettes. Native widget mappings are separate
consumers of the same palette, not proof that Flutter styling propagates there.

## Platform and accessibility acceptance

- Windows: compact mouse/keyboard layout, visible focus, scoped shortcuts,
  context menus, resize and work-area/DPI-aware owned popups. Keep native widget
  shell/input behavior and stored placement. Observe actual OS behavior separately.
- Android: Material/touch expectations, at least 48 logical-pixel touch targets
  where applicable, safe/IME insets, Back and gesture navigation, rotation,
  TalkBack, font scaling and process recreation. Equivalent outcomes need not
  have identical desktop/mobile layouts.
- Apply relevant WCAG 2.2 AA principles and native guidance: normal text 4.5:1,
  large text 3:1, required component/state identification generally 3:1 (observe
  exceptions). CSS target criterion 24x24 with spacing/exceptions is distinct
  from Android's 48dp target recommendation. Never substitute one unit for another.
- Check text scaling/reflow, names/roles/values, reading/focus order, keyboard
  operation, visible unobscured focus, non-color states, error association/recovery,
  reduced motion, customized/high-contrast themes and supported RTL/mixed text.
  Do not disable scaling or hide essential actions to satisfy geometry tests.
- Use current primary sources in [Sources](sources.md) when implementation
  depends on evolving APIs. Automated semantics/contrast checks, visual inspection
  and real assistive technology establish different evidence. No full compliance
  claim without sufficient coverage.
