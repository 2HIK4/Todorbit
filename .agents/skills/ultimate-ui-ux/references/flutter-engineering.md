# Flutter UI engineering: Android and Windows

Read the sections relevant to the cause, then select checks from
[Flutter verification](flutter-verification.md). Match the project's pinned SDK;
API names and platform integration vary by version. Reuse its architecture,
controllers, domain rules and semantic tokens rather than adopting a new state
framework or component package to fix a UI defect.

## Constraints, spacing and responsive layout

- Trace incoming constraints at the failing RenderObject through parents. A
  `Row` with unconstrained text may need `Flexible`/`Expanded`; `Expanded` in an
  unbounded scrolling axis is a different problem. Do not add either blindly.
- Use `LayoutBuilder` for local available space, `MediaQuery` for view/environment
  information. Break at the width required by real content, not device labels.
  Preserve draft and selection when switching stacked/side-by-side arrangements.
- Compare repeated padding, gaps, control heights, icon hit boxes and text baselines
  against existing tokens. Distinguish optical alignment from glyph bounds; do
  not force multiline controls to a single-line fixed height. Test real long labels.
- Give short/narrow dialogs bounded width/height and an intentional scroll region;
  keep actions reachable and reserve footer clearance. Avoid intrinsic layout on
  large lazy lists or wrapping all content in shrink-wrapped nested lists.
- Check the supported minimum window and either side of each affected breakpoint,
  short landscape, text scale and custom fonts. Fix constraint errors instead of
  suppressing Flutter overflow diagnostics or shrinking essential text to fit.

## Safe areas, system insets and Android IME

- Distinguish `padding`, `viewPadding` (system safe bounds) and `viewInsets`
  (obscured area, typically IME). Inspect which ancestor consumes them. `SafeArea`
  alone is not a complete keyboard-avoidance policy; avoid applying insets twice.
- Check `Scaffold.resizeToAvoidBottomInset`, dialog/sheet constraints, bottom
  actions and nested `MediaQuery` data before adding manual bottom padding.
- Exercise first focus, IME opening/closing, switching fields, Next/Done, multiline
  Enter, validation while IME is open and Back. Back may first dismiss IME; a
  later route pop must still protect unsaved work under the app's policy.
- Keep `FocusNode` and `TextEditingController` ownership stable and dispose owned
  objects. Rewriting controller text on every rebuild can reset selection,
  composition and cursor position. Preserve composing input and autofill intent.
- If revealing an input is necessary, use the existing reveal mechanism after
  layout/insets are valid. Check focus, scroll owner and geometry first; repeated
  `ensureVisible`/`jumpTo` in build or arbitrary delayed retries can cause shaking.
- Verify edge-to-edge/cutout/navigation-bar behavior in the actual Android target;
  synthetic `MediaQuery` insets prove only the widget's response to those values.

## Windows windows, DPI and auxiliary surfaces

- Layout uses logical pixels; runner/native geometry may use physical coordinates.
  Check each conversion once at the boundary. Test resize while a menu/editor is
  open, minimize/restore, supported minimum size and monitor/DPI changes.
- Popup ownership and work-area bounds must follow the current window/monitor;
  avoid cached global coordinates. Preserve saved geometry and clamp only as the
  product requires, without resetting established user placement preferences.
- Respect Windows keyboard focus, Tab/Shift+Tab, Enter/Space, Escape, context menus,
  wheel, hover and shortcuts scoped away from active text editing. Keep compact
  Fluent conventions; do not impose touch density on every desktop control.
- Flutter widget tests do not establish native HWND focus, Explorer hosting,
  physical DPI, shell attachment, capture or WinForms/ToolStrip behavior. Select
  native self-tests and actual platform checks using project policy.

## State ownership, lifecycle and persistence

- Map draft, committed domain state, preferences, projections and transient UI
  state to their actual owners. Watch the right provider/notifier; immutable
  replacement and correct invalidation should propagate to all consumers.
- Inspect `initState`, `didUpdateWidget`, subscriptions and dispose paths when a
  reused editor displays a different record. Use stable identity keys; do not
  generate a new key, controller, future or stream on each build.
- Do not start persistence, notifications or navigation as a build side effect.
  Guard repeated actions, order/cancel stale async completions, check mounted
  state where needed and release listeners/timers. Avoid post-dispose updates.
- Keep deliberate edits when a refresh arrives; use existing stale-write/conflict
  rules. App pause/resume and process death differ: in-memory state alone cannot
  prove promised restoration. Do not newly persist sensitive drafts without policy.
- For UI settings, verify immediate consumers, close/reopen and restart separately;
  preview/cancel must not accidentally commit. Test old/malformed settings via the
  existing validation path without deleting profiles or resetting preferences.

## Configured colors, themes and selected states

- Follow [value tracing](fix-patterns.md#configured-values-and-colors) from picker
  to draft, controller, stored representation and every renderer/projection.
- Inspect `Theme`, `IconTheme`, local icon/text colors, `DefaultTextStyle`, opacity,
  `ColorFilter`, custom painters and `WidgetStateProperty` resolution. A parent
  foreground or selected/disabled style can override a correct stored color.
- Distinguish configured icon/marker color from an `on*` foreground intentionally
  chosen for contrast. Verify that both purposes remain visible; do not copy a
  contrast foreground back into the saved configuration.
- Inspect nested `Theme`/cached painters and custom palette propagation. Cover
  light/dark/custom and live switching with dialogs open, including selected,
  focused, pressed and disabled states. Do not replace semantic roles with literals.

## Forms and dependent input

- Keep stable form/field keys and validation triggers. Validate changed
  dependencies, not every untouched field on every keystroke. Preserve draft,
  cursor, focused input and reachable actions when helper/error text changes.
- Use appropriate keyboard/actions/formatters while allowing legitimate partial
  input. Parse localized display separately from canonical dates/instants.
- Apply the conditional [dependent-field policy](fix-patterns.md#dependent-date-and-time-fields)
  before changing start/end behavior. The domain/repository must still reject
  invalid data; UI assistance does not replace validation.
- Add/remove dynamic fields with stable IDs, clear labels and predictable focus.
  Verify the submitted model and reopen result, not only error-string presence.

## Menus, overlays and dialogs

- Prefer the existing shared dropdown/menu. Identify whether covering the trigger
  is a documented selected-item alignment or a defect; menus normally open below
  when space permits, but respect deliberate platform behavior.
- Inspect actual anchor rectangle, `Directionality`, nearest/root overlay,
  transforms, clipping and safe/IME bounds. Prefer anchored layout APIs such as
  the project's `MenuAnchor` or composited target/follower implementation over
  cached offsets. A follower still needs collision/bounds handling.
- Constrain long menus, flip/shift at edges, keep selection/focus visible and
  recompute on scroll/resize/inset change (or dismiss intentionally). Check
  nested modals, barrier click-through, outside dismissal, Escape/Back, arrows,
  Enter and focus restoration to an existing opener.
- Dialog content and actions must fit the usable viewport, including large text.
  Test drafts on cancel/barrier/Back and focus trapping, not only open/close.

## Scrolling and layout stability

- Identify one intended scroll owner per region/gesture. Bound nested viewports;
  distinguish `NestedScrollView` coordination from independent inner lists.
  Avoid simultaneous primary controllers or attaching one controller where a
  single-position API is required but multiple scrollables attach.
- Preserve keys/controllers and restoration identity across validation/filter/
  state updates. Inspect offset, max extent, focused field and a visible anchor
  before/during/after a shift. Offset may legitimately change to keep focus visible
  or clamp after content shrinks; assert user-visible stability, not blind equality.
- Keep helper/error layout predictable (bounded reserved region when appropriate,
  otherwise natural wrapped height). Avoid hard-coded one-line reservations that
  clip translated errors. Do not repeatedly autoscroll to an already visible field.
- For lazy lists, retain item IDs across insertion/reorder, selection and restored
  scroll. Verify last item/footer and wheel/touch/keyboard independently.

## Accessibility, motion and performance

- Use actual `TextScaler` and measured text where supported; do not assume nonlinear
  OS scaling is a constant multiplier. Do not globally disable/clamp text scaling
  to hide overflow. Check wrapping, hit targets, semantics, focus and RTL ordering.
- Custom controls/painters need names, roles, values and keyboard behavior. Avoid
  duplicate semantics from icon plus parent label. Exercise TalkBack and Windows
  assistive technology when available; report the exact unobserved combinations.
- Preserve controller identity for animations; test interruption, reduced motion,
  theme changes and input while animating. An invisible exit must not retain hit
  tests/focus. Avoid animating validation height to conceal unstable layout.
- Profile input/scroll/theme jank with representative data in profile/release mode;
  debug timing is diagnostic only. Measure rebuild/layout/paint and frame costs
  before optimizing. Prefer bounded rebuilds and lazy lists, not speculative
  caches or `RepaintBoundary` everywhere; inspect disposal/memory over repeated use.

## Native widgets and project adaptation

Android RemoteViews and Windows companion surfaces are not Flutter-rendered
widgets. Trace their data projection, theme mapping, stable navigation target,
privacy policy and lifecycle independently. Check configuration, resize,
empty/populated, update, app closed/locked and activation without losing drafts.
Native render harnesses do not prove launcher/OEM/shell or physical input behavior.

In Todorbit, use the repository architecture map and UI workflow, shared
`AppController`/`LifeRepository`, theme/spacing tokens and existing profile stores.
Keep date-only plans, deadlines, UTC sessions, actual work and fixed events
separate. Respect Microsoft Fluent guidance, Android Back/touch conventions and
native evidence gates. Never migrate/reset data or change cloud/product policy
as a UI repair. These are project constraints, not requirements for other apps.
