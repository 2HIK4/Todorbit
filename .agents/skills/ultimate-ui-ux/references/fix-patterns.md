# Durable UI fix patterns

Prefer correcting causes over masking symptoms. Every pattern is conditional: inspect project conventions and test the result.

## Typography and spacing

- Create a purposeful typography hierarchy: title, heading, body, label, secondary/caption, all with distinct jobs. Avoid all text at one font size and opacity. Check contrast after adjusting secondary text.
- Use semantic design tokens for `text.primary`, `text.secondary`, `surface`, `border`, `action`, `danger`, `focus`, spacing and motion; reuse the existing naming system.
- Fix misalignment with flex/grid alignment and consistent component padding. Do not rely on `margin-left: -7px` or one-off transforms to compensate for a flawed parent layout.
- Preserve clear relationship between heading and its content (closer) versus unrelated sections (further). Don't force every gap to be identical.

## Web layout

- For flex and grid items with long content, evaluate `min-width: 0` / `minmax(0, 1fr)` as appropriate; use wrapping and sensible max widths before clipping.
- Use adaptive columns, fluid gutters, viewport constraints and device-independent breakpoints for intended content.
- Don't `overflow: hidden` the body globally just to silence horizontal overflow; isolate and correct the offending element.
- Test fixed/sticky headers and footers against scroll targets, keyboard viewport and safe-area insets.
- For floating UI, use overlay components that manage portal root, collision detection, focus, dismissal semantics and scroll interaction.

## Interactive controls

- Prefer real HTML `button`, `input`, `label`, `dialog` or framework equivalents rather than custom `div`-based controls without semantics.
- Pair affordance with real handler. Validate the action's resulting data and any asynchronous success/error, not only state styling.
- Prevent duplicate submissions at UI and backend when needed; keep controls accessible while loading via status feedback.
- Preserve edits across validation failures; warn before losing unsaved information.
- For modals: define opener, focus entry, focus trap, escape/outside policy and restoration. Validate with keyboard and screen reader.

## Web accessibility

- Start with semantic elements and accessible names. ARIA does not replace missing keyboard behavior or visual affordance.
- Focus indicators must survive themes. Colors must be checked on the final rendered surface, including opacity and disabled states when appropriate.
- Form errors should be associated with field, detectable by assistive tech and accompanied by recovery guidance.
- Responsive zoom may require reflow; hiding essential actions to satisfy a visual snapshot is not a solution.

## Animations

- Prefer no animation for highly frequent input/keyboard actions. For purposeful motion, prioritize interruptibility, appropriate spatial origin and reduced-motion alternatives.
- Prefer `transform` and `opacity` for many animations when performance matters; avoid repeatedly animating layout dimensions when unnecessary.
- Design entry and exit animations to feel immediate and coherent with surface hierarchy, rather than applying a blanket transition rule.
- Never use motion alone to convey essential state.

## RTL, content and theming

- Use logical CSS properties (`margin-inline-start`, etc.) and correct `dir` behavior for internationalized web layouts.
- When Arabic/Hebrew and English technical identifiers mix, isolate text direction at the smallest meaningful scope and test final rendering.
- Preserve original token semantics across light/dark/high contrast. Ensure theme changes restore after reload and do not cause momentary flashes.
- Never silently remove or shorten important information to improve cosmetics. Prefer disclosure, expandable details and accessible tooltip alternatives.

## Native and Flutter notes

- Flutter: verify `MediaQuery` text scaling, `SafeArea`, flexible constraints, overflow detection, widget focus/semantics, screen readers, platform navigation, theme persistence; favor existing widgets/theme tokens over excessive custom drawing.
- Android/iOS: honor OS keyboard/window insets, system Back, assistive tech and Dynamic Type/font scaling; choose native patterns for expected interactions.
- Desktop widgets: independently test process/window lifecycle, focus and input after main process closes, multi-monitor placement, DPI changes and persisted appearance.

## Example failure-to-fix investigations

| Symptom | Root cause candidates | Durable repair and verification |
|---|---|---|
| Helper labels as white as headings | hardcoded text color; no type scale | semantic secondary text style with compliant contrast; compare hierarchy in both themes |
| Tooltip clipped by card | overflow clipping or stacking context | reposition/portal overlay; verify at screen edges and scroll |
| Slider label flashes between black and white | competing hover/theme state styles | remove conflicting state source; verify slow hover and theme transitions |
| Dialog save hidden under keyboard | fixed-height modal, no inset support | scroll-aware/inset-aware layout; test small phone + IME |
| App popup behind window | wrong window ownership/layer | correct parent/owner and stacking; test on multi-monitor |
| Calendar indicator crosses cell border | indicator painted at wrong offset/clip | align geometry inside cell based on size constraints; test selection, scaling and themes |
| UI settings reset after update | migration/default overwrote persisted preference | fix migration path; test upgrade rather than fresh install only |
| Button says saved when server fails | optimistic success feedback | reconcile result/error, rollback when necessary; force failure and verify message |
| `overflow-x: hidden` hides actual defect | rogue fixed-width child | identify child and make responsive; confirm intended content remains reachable |
| Popup works on mouse, fails on keyboard | pointer-only handler, missing focus | semantic trigger and keyboard handling; Tab/Enter/Escape focus test |

## Avoid these tempting shortcuts

- Random global CSS overrides, increased z-index everywhere, fixed heights to match screenshot, arbitrary negative margins, hiding overflow to silence bugs.
- Aesthetic overhaul of a mature product without explicit permission or before/after checks.
- Snapshot-only claims of correctness; no testing of interaction, invalid inputs, slow network, and other themes.
- `aria-label` sprinkled on nonsemantic components while leaving keyboard handling broken.
- Installing animation, design system or component packages just to fix one small behavior.
- Erasing broken tests, bypassing validations, or declaring passes after tool failures.
