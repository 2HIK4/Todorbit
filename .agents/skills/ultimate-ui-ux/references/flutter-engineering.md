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
- Stacked form controls: compare label/input bounds and apply existing related-field
  spacing where they collide. Test floating labels, errors and wrapped helper text
  at larger text sizes; do not rely on borders alone to separate controls.
- Modal/editor footer clearance: distinguish an overlaid footer from a sibling
  below the scroll view. Reserve measured overlay/IME space only where needed;
  use existing spacing tokens for ordinary separation. Verify the last control
  remains reachable at narrow sizes and larger text, without arbitrary 48-64dp rules.
- Give short/narrow dialogs bounded width/height and an intentional scroll region;
  use `AppModalShell` / `showAppModal` to enforce `AppLayout` dialog bounds and automatic
  keyboard avoidance (`media.viewInsets.bottom`). Keep actions reachable and reserve
  footer clearance. Avoid intrinsic layout on large lazy lists or wrapping all content
  in shrink-wrapped nested lists.
- Form inputs and in-place validation: show errors directly on the control via
  `InputDecoration(errorText: ...)` and clear upon typing. Do not rely exclusively
  on `ScaffoldMessenger.showSnackBar`, which appears off-screen on desktop side panels
  or below modal dialog overlays.
- Accessible hit targets: ensure all interactive icon buttons, clear actions, and
  tappable surfaces enforce minimum touch targets (`AppLayout.minTapTarget = 48` dp)
  using `BoxConstraints(minWidth: AppLayout.minTapTarget, minHeight: AppLayout.minTapTarget)`
  and explicit `Semantics(button: true, label: ...)`.
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
- Shortcut Bubbling & Dismissal Hygiene: Subviews with `CallbackShortcuts` (such as
  `Escape` in a calendar or canvas) must not unconditionally consume the key if idle
  (e.g. no active gesture/drag); they must propagate to parent dismissal callbacks (`onEscape`)
  or let the key bubble up so parent pane navigation or editor dismissal functions properly.
- Detail Presentation & Route Singularity: When supporting both docked (side-panel)
  and full-page detail presentations, enforce exactly ONE active presentation route/state
  derived from configuration. Closing an editor must atomically clear selection and all
  presentation flags so closing never reveals a secondary/stale editor underneath.
- Non-Disruptive Save Feedback: Avoid popping Scaffold-level floating SnackBars for routine
  nested sub-form or prerequisite saves; floating SnackBars can intercept pointer hit-testing
  aimed at action buttons docked at the bottom of narrow or side-panel layouts.
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
- Rounded interactions: inspect the actual Material and ink shape. Use matching
  border radii or local `clipBehavior: Clip.antiAlias` for affected interactive
  cards when necessary, then inspect pressed/selected/focused frames. Do not infer
  leakage from `Clip.none` alone or impose global clipping without consumer review.
- Calendar selection: distinguish Today from the selected date and provide a clear
  return-to-Today action. Follow Today must advance at foreground rollover and
  resume; deliberate browsing must survive lifecycle refresh. Date-picker and
  deep-link paths need the same explicit mode handling as day-cell selection.

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

## Shared presentation components and deduplication

- Discover and inspect existing shared components in `lib/features/shared/` before implementing new UI or modifying existing screens:
  - `AppTaskRow`: Canonical task row presentation across desktop and mobile surfaces. Encapsulates title wrapping, completion checkbox semantics, planned date vs deadline distinction, overdue warning styling, priority flag / theme tokens, and subtask/checklist badges. Replaces duplicated ad-hoc task list rows.
  - `AppModalShell` / `showAppModal`: Standard dialog container enforcing `AppLayout` responsive constraints (`dialogDefaultWidth = 520`, max height 680) and keyboard avoidance.
  - `AppLayout` & `AppSpacing`: Centralized breakpoints (`breakpointCompact = 600`, `breakpointMedium = 1050`, `breakpointWide = 1200`), panel widths (`panelDefaultWidth = 370`), dialog widths, and tap target minimums (`minTapTarget = 48`).
  - `TodorbitThemeTokens`: Semantic priority colors (`priorityLow`, `priorityMedium`, `priorityHigh`) and status colors with helper `colorForPriority(priority)`.
  - `SettingsSection`: Grouped card container with collapsible headers and optional descriptions. Avoid showing redundant helper microcopy on existing persisted records.
- Preserve separation of concerns:
  - Presentation widgets (`AppTaskRow`, `AppModalShell`, etc.) must remain purely presentational or state-binding without embedding database transactions, SQLite queries, or direct navigation side-effects.
  - Callers pass down domain models (`LifeTask`), pre-resolved progress/prerequisite counts, and callback handlers (`onToggleComplete`, `onTap`, `trailingActions`).
  - Distinguish intentional presentation variants (e.g. desktop `Wrap` badges vs mobile `ListTile` rich text subtitles) from accidental duplication of business rules or data parsing.

## Explicit UI & Reliability Quality Gates

Every UI modification, new component, or bugfix must pass these 16 explicit quality gates:

1. **Keyboard-Inset & Viewport-Aware Dialogs**:
   - Dialogs and modal sheets must be wrapped in `SingleChildScrollView` or a viewport-bounded scrollable container with bottom padding accounting for `MediaQuery.viewInsetsOf(context).bottom`.
   - Never allow keyboard presentation to trigger `A RenderFlex overflowed by X pixels` on small screens or landscape viewports. Actions row must remain accessible without requiring dismiss of the IME.
2. **Responsive Breakpoints & Text Scaling**:
   - Layouts must be validated across 1.0× to 2.0× text scaling (`MediaQuery.textScalerOf(context)` or `.clamp(1.0, 2.0)`).
   - Use flexible metadata rows (`Wrap` or flex with overflow handling); do not fix card heights to single-line bounds that clip wrapped text. Breakpoint transitions (600dp, 900dp, 1200dp) must not recreate controllers or drop in-progress user drafts.
3. **Focus, Hover, and Window-Focus Cancellation**:
   - Hover states, pointer highlights, and tooltips must cleanly dismiss when the pointer leaves or when the desktop window loses OS focus.
   - Drag receivers (`DropTarget`) and gesture recognizers must cleanly unregister on widget disposal or window blur without leaking event loops.
4. **Identical Card Geometry Across Item Variants**:
   - Items in repeaters/lists/agendas (task cards, calendar entries, subtasks) must maintain identical baseline padding, horizontal margins, minimum heights, and leading checkbox alignments regardless of optional badges (subtask count, priority tag, recurrence indicator, due date).
   - Changing task attributes must not cause vertical geometry jumps or stuttering during scrolling.
5. **Parent-Child Continuity**:
   - Navigating into child subtasks, attachments, or detail views from a parent must preserve the parent list's scroll position and selection state.
   - Returning (via Back, Save, or breadcrumb) must cleanly restore focus and scroll offset to the exact parent record without jumping to the top of the collection.
6. **Recurrence Grouping & Identity**:
   - Recurrence series entries and individual occurrence overrides/exceptions must maintain unambiguous visual and domain identities.
   - Editing or completing an individual occurrence must never mutate or detach the entire series without explicit user choice and clear confirmation.
7. **No Duplicated Task Routes**:
   - Navigation flows must guard against pushing duplicate routes or opening multiple concurrent editors for the same task/entity (e.g. rapid multi-taps or opening from both sidebar and list).
   - Check existing navigator stack / active route state before pushing.
8. **Idempotent Timers**:
   - Focus, Pomodoro, Stopwatch, and auto-save timers must be strictly idempotent: calling `start()` multiple times must never spawn parallel ticking loops or double-decrement intervals.
   - Monotonic elapsed time must always be calculated from authoritative UTC timestamps (`DateTime.now().toUtc()`), never by summing periodic timer ticks. All `Timer` references must be cancelled and nullified in `dispose()`.
9. **Controlled Scroll Position**:
   - Scrollable surfaces (task lists, calendar agendas, category boards) must maintain their scroll offsets across filter changes, task completions, and `AppController.refresh()` via stable `PageStorageKey` or persistent `ScrollController` offsets.
10. **State-Preserving Asynchronous Navigation**:
    - Asynchronous workflows (saving, sync, network/file I/O) must check `if (!mounted) return;` before calling `setState()` or `Navigator.pop()`.
    - Never discard uncommitted user drafts if navigation or cancellation occurs before background I/O finishes.
11. **Destructive-Action Clarity**:
    - Destructive actions (Empty Trash, Delete Task, Delete Series, Discard Draft) must require explicit modal confirmation.
    - Dialogs must use clear, unambiguous copy stating exact consequences, red/destructive styling on the confirm action, and safe non-destructive action on <kbd>Esc</kbd> / Cancel.
12. **Animation Restraint & Reduced Motion**:
    - Query `MediaQuery.disableAnimationsOf(context)` or system accessibility settings. If reduced motion is requested, immediately jump or use fast fading (<=100ms) instead of spatial slides or bounces.
    - Keep normal animations subtle (150-250ms); avoid gratuitous spring physics that hinder task completion.
13. **Android Content URI Permissions**:
    - File attachments picked via Android `ACTION_OPEN_DOCUMENT` / `ACTION_GET_CONTENT` require `takePersistableUriPermission` across app restarts and reboots.
    - If persistable permissions cannot be obtained, copy bytes into managed app storage (`LifeRepository` managed attachments). Never store transient `content://` URIs expecting long-term access.
14. **Load-Time & Performance Evidence**:
    - Performance or responsiveness optimizations must be backed by measured DevTools / timeline evidence (startup p50/p95, frame render times, query counts) before and after changes.
    - Never claim "faster UI" or "reduced lag" without concrete profiler metrics.
15. **Accessible Text, Contrast & Keyboard Navigation**:
    - Enforce WCAG AA contrast ratios (>=4.5:1 for normal body text, >=3:1 for large text and key UI components).
    - Provide `Semantics(label: ...)` for all icon-only buttons. Ensure full keyboard traversal (<kbd>Tab</kbd>, <kbd>Shift</kbd>+<kbd>Tab</kbd>, <kbd>Enter</kbd>, <kbd>Space</kbd>, <kbd>Esc</kbd>) across all navigable screens.
16. **Targeted Widget & Integration Tests**:
    - Every UI change must be accompanied by focused widget tests exercising responsive constraints, text scaling (1.0× vs 1.5×/2.0×), and keyboard insets where applicable.
    - Prioritize fast behavioral widget tests over brittle full-screen golden tests.
