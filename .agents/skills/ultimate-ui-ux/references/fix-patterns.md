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

## Configured values and colors

Use when selection looks correct in an editor but is missing, white, stale or
different in another view. Trace one stable entity ID and two distinctive values:

| Boundary | Inspect | Correction/verification target |
| --- | --- | --- |
| Selection -> draft | callback, canonical key/ARGB/HEX/alpha, selected state | draft receives the intended value; preview/cancel honor the draft contract |
| Draft -> committed state | copy/update path, notifier and async ordering | correct field/identity changes once; failure retains edits without false success |
| State -> storage -> reload | codec, allowlist, defaults, old/malformed format | compatible round trip; defaults apply only when absent/invalid, not to every load |
| Record -> projections | list/calendar/detail/native widget mappers and caches | all relevant presentations receive the same configured semantic value |
| Projection -> paint | local/theme icon color, foreground resolution, opacity/filter, painter cache | actual marker uses configuration; intentional contrast foreground remains readable |

Find the first divergent boundary; do not hardcode a renderer color to hide a
mapping or stale-state bug. An icon's configured color and a foreground chosen
for legibility are different roles: document which part displays the selected
color. Compare selected/unselected/disabled, light/dark/custom, live update,
navigation and restart. Regress sibling entities, exports/imports and native
projections only when they consume the changed representation.

## Dependent date and time fields

First establish the domain: date-only plan/deadline, optional interval, fixed
event, recurrence or actual work. Determine ordering, equality/zero duration,
duration semantics, timezone storage and whether automatic assistance is allowed.
Do not turn every task into an event or silently reschedule saved records.

For a draft interval, a conditional policy may be:

| End state when start changes | Predictable assistance |
| --- | --- |
| End absent and optional | Keep absent; do not invent an end |
| End generated/untouched | If domain permits, derive from new start + valid prior/default duration, including the date across midnight |
| End explicitly edited and still valid | Preserve it; recalculate displayed duration if appropriate |
| End explicitly edited and now invalid | Keep the deliberate value with clear inline resolution/confirmation, or apply an already documented assistance rule; do not silently overwrite it |
| Start is incomplete/unparseable | Retain draft; defer dependent arithmetic until valid input exists |

Track explicit editing separately from a generated value; batch related draft
updates to avoid transient invalid renders and recursive listeners. Explain any
automatic adjustment near the field and retain correction/undo where appropriate.
Safe assistance in a draft does not authorize changing other records.

For zoned wall times, use existing domain conversion: distinguish elapsed duration
from calendar/wall-clock duration, handle DST gaps/folds with the product's
resolution policy, and keep date-only values out of UTC arithmetic. Check both
date and time, midnight/month/year boundaries, earlier/later start, explicit end,
optional end, cancellation, timezone changes and persisted reload. Regress shared
pickers, recurrence, reminder projections and Windows/Android editors as affected.

## Popup positioning investigation

1. Record trigger/panel rectangles, usable viewport/work area, overlay owner,
   scroll offsets, transforms, insets, direction and active keyboard. Determine
   whether selected-item overlap is intentional platform behavior before patching.
2. Locate the shared anchor/collision code and its callers. Check coordinate-space
   mixing, stale measurements, ancestor clipping and the wrong overlay/owner.
3. Normally place below the trigger with a consistent gap if space allows; flip,
   shift or constrain/scroll the panel when it does not. Preserve access to trigger
   and selected options; raising a global z-index does not fix bad geometry.
4. Recheck top/bottom/side edges, long options, RTL, enlarged text, scrolled
   parents, nested modals, keyboard and window/DPI change. Verify pointer selection,
   arrows/Enter, Escape/Back, outside click, no click-through and restored focus.
5. Cover distinct shared consumers and platform adapters, not just the reported
   dropdown. Do not replace all menu implementations without a confirmed cause.

## Scroll jumping, shaking and flicker investigation

Capture before/during/after validation/load/theme transitions, including repeated
identical triggers. Record scroll offset/extent, visible anchor, focused field,
error/helper dimensions and rebuild/observer count. Distinguish a legitimate
focus reveal or content shrink clamp from repeated unrequested movement.

Inspect unstable keys/controller creation, conditional helper rows, competing
validation/focus listeners, async error races, nested scroll owners, changing
insets and repeated reveal calls. For color/text flicker, trace multiple writers,
hover/selection theme resolution and transient defaults between loaded values.

Repair the responsible state/layout contract: stable identity, one scroll owner,
bounded focus reveal, predictable wrapping/error region and ordered updates. Use
reserved space only when it accommodates supported messages/scales. Do not add
offset corrections, repeated timers or animations that conceal the shift.

Recheck invalid -> invalid -> corrected with different message lengths, short
viewport, large text, IME, keyboard traversal, nested dialogs and navigation back.
Assert draft, cursor and anchor stability within expected layout change; inspect
intermediate frames so a settled screenshot cannot hide oscillation. Regress
shared fields, banners, lazy lists and validation consumers with the same cause.

## Interactive canvas, gesture and calendar patterns

| Symptom | Root cause candidates | Durable repair and verification |
|---|---|---|
| Auto-scroll jumps upward on card drag start | Pointer distance calculated against card coordinates (`localPosition.dy < margin`) instead of viewport bounds | Convert pointer to viewport coordinate (`localInColumn.dy - scrollOffset`); auto-scroll only when viewport distance `< 48px`; tick continuously (30ms) |
| Touching Month card on mobile prevents scrolling | Immediate pointer `Draggable` intercepts vertical pan gestures | On Android/iOS, adapt cards to `LongPressDraggable` (250ms delay, haptic feedback) and enable `ClampingScrollPhysics` on grid; desktop keeps instant `Draggable` |
| Timeline scrolls vertically while zooming view modes | Pointer wheel events bubble to `SingleChildScrollView` while <kbd>Ctrl</kbd> is pressed | Implement `CalendarScrollPhysics.shouldAcceptUserOffset` returning false when Ctrl is pressed; debounce view mode transitions by 350ms in `CalendarZoomController` |
| Floating notification banners stack and linger | Persistent full-width `SnackBar` without auto-dismiss or dismissal of previous banner | Replace with floating 420px notification with `Duration(seconds: 4)` and `messenger.removeCurrentSnackBar()` before displaying new notice |
| Current time rule looks like a broken pink line | Unlabelled line drawn with `scheme.error` and zero text metadata | Replace with primary accent rule, circular pip, live formatted time badge (`HH:mm`), and accessible tooltip |
| Native desktop widget navigation buttons hard to click | Small hit bounds (32×28), text glyphs (`‹`, `›`), no hover state | Increase bounds to 32×32, use vector arrow rendering (`DrawCalendarArrow`), and draw Fluent accent hover/pressed rounded outlines |

## Proactive investigation boundary

Map symptom -> shared owner -> materially different consumers -> observable
contracts. Inspect adjacent selected/disabled, empty/error and lifecycle states
for the same cause (for example repeated notifications from build-side effects,
settings delayed by stale subscriptions, clipped icons from fixed-height rows or
navigation reset from unstable keys). Confirm before editing. Include low-risk
repairs within the authorized task and record larger or preference-changing
ideas separately. These examples guide detection; they are not claims that a
particular project currently contains the defects.
