# Runtime UI audit: evidence and coverage matrix

## 0. Inventory first

Enumerate from repository and runtime, without assuming missing views do not exist:

- Platforms/app targets and minimum supported versions.
- Routes/screens, main navigation, settings, wizards, onboarding, authentication, permission flows, widgets, subsidiary windows.
- Reusable components: buttons, inputs, date pickers, lists/tables, cards, menus, dropdowns, tooltips, toasts, dialogs, sheets, drawers.
- Each component's prop/state variants, async operations, destructive actions and persistence.
- Internationalization languages, supported themes, input methods, text size and display configurations.
- Critical flows and workflow owners; observed production/telemetry issues if available and user-authorized.

For a full audit follow the [audit workflow](audit-workflow.md) and create a
coverage map with `Surface ID/entry | owner/shared consumers | platform | risk |
variants/check | applicability | execution status | evidence`. Use its five
execution statuses; N/A is separate applicability. Don't claim 'all screens'
unless mapped and genuinely visited. Minor fixes need only affected rows.

## 1. Select risk-based combinations

The Cartesian product of platform × screen × state × theme × viewport × language × input mode is huge. Use **pairwise sampling plus high-risk targeted cases**. Always test critical paths on representative devices and every materially affected shared component in its core states.

| Dimension | Minimum representative tests | Additional when relevant |
|---|---|---|
| Screen width | narrow phone (~320-390 CSS px), wide phone (~430), tablet (~768), laptop (~1280), large desktop (~1920) | ultra-wide, split-screen, tiny desktop window, foldable |
| Screen height | short phone/small laptop; standard | landscape, soft keyboard, fixed footer, dynamic browser chrome |
| Browser/web engine | at least Chromium plus the other engines actually supported | Safari/WebKit, Firefox, iOS Safari, embedded WebView |
| OS/device | target reference OS/device and release build | older supported release, low-memory phone, HiDPI monitor, multiple monitors |
| Theme | light and dark if both supported | custom themes, system auto, high contrast, theme change while view open |
| Content | typical, empty, very long/unusual, many records | null/missing, mixed Arabic/English, extremely large values, invalid file |
| Interaction | pointer/mouse, keyboard-only; touch where supported | stylus, drag-and-drop, gestures, screen reader |
| State | default, focus, disabled, loading, success, error | offline, timeout, partial load, permission denied, stale/conflict, retry |
| Text | base, 200% text resize, 200% page zoom | 400% zoom/reflow, OS dynamic type max supported, large accessibility fonts |
| Motion | standard and reduced-motion | slow device, animation interruption |
| Session | first load, navigate away/back, restart/refresh | background/resume, session expiry, concurrent edits |
| Locale | default + RTL if supported | language switch, longer translations, locale numbers/dates/currencies |

Tests are context-dependent: don't test Safari for a Windows-only app unless it ships a browser interface. Don't test OS-only widget behavior via web screenshots. If a screen has no meaningful empty state, mark **N/A**, not PASS.

Sizes above are examples, not mandated product breakpoints. Record CSS pixels for
web, logical pixels plus DPR for Flutter, and physical/native coordinates where
needed. Separate OS font scale, page zoom and display DPI. Include just-below/at/
above changed breakpoints, live resizing and high-risk intersections such as
short phone + IME + error + large text, not only isolated dimension checks.

## 2. Minimum interaction journey probes

For each relevant high-value screen, exercise:

1. Reach via expected navigation and via direct/deep link if applicable.
2. Verify the visual hierarchy, readable text, icon placement, meaningful primary action.
3. Tab/keyboard flow: visible focus, order, enter/space and escape/back semantics.
4. Main success path with real input and confirmation of resulting state.
5. Validation path for invalid input; error near control, preserved data and recovery.
6. Loading plus slow/failure path using controlled mocks or environment if supported.
7. Small viewport and zoom/text increase; watch overflow/clipping/hidden controls.
8. Dialogs, menus, tooltips, toasts, nested scroll and overlay ordering.
9. Other supported theme/locale; ensure state tokens and layout adapt.
10. Navigate away/back, refresh/restart or background/resume; check persistence, stale state, duplicates.

## 3. Specialized probes

- **Web:** examine console errors/warnings related to UI, visual viewport, actual computed colors, focus ring, DOM semantic roles, accessible names, responsive capture, browser Back/Forward, hydration mismatch, slow network and 4xx/5xx.
- **Angular/React/Vue:** watch stale props, change detection cycles, unstable repeat keys, cleanup of listeners/subscriptions, asynchronous racing, form binding errors, route state loss.
- **Flutter:** release build when feasible, multiple `MediaQuery` sizes/text scaling, `SafeArea`, layout overflow diagnostics, theme state restoration, widget test/golden comparators when applicable, Android and desktop input semantics, TalkBack/VoiceOver if available.
- **Native Android:** font scaling, navigation bar/IME insets, system Back, dark mode, accessibility semantics, gesture navigation, rotation and process recreation, TalkBack.
- **Native iOS:** Dynamic Type, safe areas, VoiceOver, reduce motion, modal sheet dismissal, keyboard avoidance, back gestures.
- **Windows/macOS desktop:** DPI/scale changes, window min/max/resizing, multi-monitor popup placement, focus switching and keyboard input, native context menus, settings persistence, desktop-widget lifecycle where present.

For Flutter implementation diagnosis use [Flutter engineering](flutter-engineering.md)
and for widget/integration/golden/accessibility recipes use
[Flutter verification](flutter-verification.md). Use an existing suitable build;
create a new profile/release build only when changed risk needs that evidence.

For web visual/interaction regression, reuse existing browser tools and fixtures:
capture stable route/state baselines, inspect computed styles and accessibility
tree, execute keyboard and form recovery, and compare before/after at chosen
viewports. Check bounding rectangles plus scroll/visual-viewport changes during
validation, menu opening and mobile keyboard. Test controlled delayed/rejected
requests, hydration/theme flashes and Back/Forward; avoid fixed sleeps and broad
screenshot tolerance. Automated scanners/screenshots complement actual operation.

## 4. Accessibility criteria and realistic claims

Aim for applicable WCAG 2.2 AA requirements on web and appropriate native equivalents, subject to actual product scope. Recommended checks:

- Text contrast 4.5:1 for normal; 3:1 for large text; distinguish large-text criteria accurately.
- Non-text controls and indicators: generally 3:1 when necessary to identify component/state, with criterion exceptions.
- Visible keyboard focus and logical order; skip links and modal focus lifecycle.
- Target size: WCAG 2.2 SC 2.5.8 AA typically 24×24 CSS px or sufficient spacing/exceptions; 44×44 is a sensible touch-design target, not universally the AA criterion.
- Text resize to 200%; reflow at an equivalent 320 CSS px width without loss for applicable content (exceptions exist for intrinsically two-dimensional layouts).
- Screen readers: names, roles, values, state updates, error announcements and reading order.
- Pointer/drag alternatives, keyboard operability, reduced motion, meaningful alt text and localized directionality.

An automated zero-violation report proves only checks the specific tool could execute. Manual accessibility tests and real assistive-tech validation remain necessary.

## 5. Severity and acceptance

| Class | Meaning | Example | Gate |
|---|---|---|---|
| P0 | Data loss, privacy breach or widespread unusable core task | Draft is silently lost; login blocked | Stop release and fix |
| P1 | Critical functional/a11y obstruction or high-impact responsive failure | Checkout action hidden, keyboard cannot reach save | Fix before release or explicitly accept with owner |
| P2 | Significant but workaround exists | Mobile table difficult, helper contrast too low | Fix in scope; track if deferred |
| P3 | Cosmetic/polish or minor consistency | Icon slightly off baseline | Batch with nearby work |

Severity depends on actual context and users; e.g. missing keyboard navigation could be P0/P1 for an essential workflow. Not all aesthetic preferences are defects.

## 6. Required test ledger

For *each test run* log:

- Test ID / timestamp, platform, device/viewport/theme/locale/input mode.
- Exact command or manual reproduction steps.
- Component/screens/flow, reason for this test and changed code/commit under test.
- Actual check result, error details, screenshot/log/video/trace reference and
  evidence level (static, widget/offscreen, runtime or physical platform).
- Prior relevant successful run and why rerun or why reuse was justified.
- If untestable, tool/device gap and what narrower evidence was obtained.

Do not rerun a huge, unchanged suite without reason. Do rerun targeted and impacted regression tests after meaningful changes; run baseline suites when risk warrants it.

## 7. Stop conditions and declaration

Say `Reviewed [specific screens/flows] on [specific matrix]. Fixed [issues], verified with [exact runs]. [count] items remain open and [count] scenarios are untested.`

Never say '100% error-free', 'fully accessible', 'perfect on every screen', 'verified all devices' or 'pixel perfect' based on limited evidence. When no issue is found, explicitly mention the covered sample and limitations.
