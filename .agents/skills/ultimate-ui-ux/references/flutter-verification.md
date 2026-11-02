# Flutter verification recipes

Use for affected UI behavior, not as a reason to run an app suite for skill or
documentation edits. Recipes are adaptation examples, not tests already run.
Use the project's pinned SDK, existing harness, fixtures, fonts, test style and
commands; add dependencies only for a demonstrated gap. Preserve personal data.

## Select the smallest meaningful evidence

| Changed boundary | First useful check | Wider evidence when required |
| --- | --- | --- |
| Layout/spacing | widget geometry at normal/narrow/short, long labels and larger text; inspect render | golden if a stable visual contract already exists; runtime resize/insets |
| Colors/theme | select value, inspect each affected renderer and state variant | repository/store round trip when mapping changes; restart and native projections |
| Dependent fields | deterministic rule cases plus editor interaction and submitted value | persistence and actual picker/timezone behavior |
| Menus/dialogs | anchor/viewport/hit-target/focus assertions in shared component and distinct consumers | runtime IME, window/DPI and native menus |
| Validation/scroll | invalid -> repeated invalid -> corrected sequence; anchor/focus/offset observations | actual IME animation, nested scrolling and platform Back |
| Navigation/state | route/action identity, draft retention, failure/retry and async order | cold/warm deep link, background/resume, restart/process recreation |
| Accessibility | semantics, keyboard and applicable SDK guidelines | actual TalkBack/Windows assistive-tech checks |
| Performance | reproduce and measure affected frames/rebuilds with realistic data | profile/release on representative hardware; no debug timing acceptance claim |

Review receipts first. Run the existing focused format/analyzer/test commands and
record source, scope and reason. Widen for shared semantics or persistence risk;
do not introduce a full build or broad golden suite for a one-control patch.

## 1. Geometry and responsive widget checks

Illustrative helper for SDKs with `TestFlutterView` and `TextScaler`. In an existing
test use its app/provider/localization harness instead of replacing it with this
minimal wrapper. Do not reset the view while testing a live resize transition.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpUiCase(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(390, 700),
  double textScale = 1,
  ThemeData? theme,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    theme: theme,
    builder: (context, content) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
      ),
      child: content!,
    ),
    home: Scaffold(body: child),
  ));
  await tester.pump();
}
```

Apply to the real widget with representative fixture data. Check:

- No reported Flutter/layout exceptions (`tester.takeException()`), including
  after interactions; an empty exception queue alone proves little.
- Required labels/icons remain reachable, full content has disclosure if clipped,
  and the final row clears fixed actions. Assert `Rect` relationships using stable
  finders and logical units; use justified tolerances, not a screenshot coordinate.
- For below-trigger placement when enough space exists, compare the actual menu
  panel top to trigger bottom and panel bounds to usable viewport. At edges assert
  containment and access, not the same direction. Select a real item and verify
  the resulting model, then test keyboard dismissal/focus restoration.
- Repeat just around the affected breakpoint, with long strings, base/2x text and
  theme variants. Synthetic linear 2x scaling is not Android nonlinear OS scaling.
- Test an actual resize on the same widget instance; verify draft, selection,
  scroll and focus survive. Re-pumping a fresh app does not prove resize retention.

## 2. Value, interaction and state-transition checks

Use public input and observable results rather than invoking private callbacks
or snapshotting the implementation's own calculated answer.

| Investigation | Sequence and assertions |
| --- | --- |
| Configured color | choose two distinctive valid colors; check draft preview, save, alternate views, close/reopen, store round trip and restart where supported; separately assert configured marker and contrast-derived foreground |
| Live setting | change once; check already-open consumers, navigation away/back, cancel vs apply and persisted reload; inject write failure and check honest recovery |
| Dependent interval | untouched automatic end vs deliberate explicit end; earlier/later start, date change, midnight, optional end, invalid/zero policy, DST/zone changes where supported; assert submitted canonical values and preserved edits |
| Stale response | arrange controlled A/B completion out of order; newer deliberate selection must win under project concurrency policy; unmount during pending work without leaks |
| Notifications | repeat rebuild/resume/retry around one logical event; observe count/identity and dismissal under existing delivery policy, not just one toast at one instant |
| Navigation | create draft, open popup/error, Back/Escape/cancel, follow external target and return; assert intended route/record and draft remain correct |

For date rules, define expected input/output cases from product behavior before
implementing. Use controlled clocks/zones if already supported. Do not assume
every task has an interval or test DST with only the host's current time zone.

## 3. Validation, scrolling and keyboard stability

1. Populate a long editor and scroll to a real field. Record visible anchor rect,
   scroll position, focused control and current draft.
2. Trigger validation, repeat unchanged validation, edit, then resolve. Capture
   intermediate frames as well as the settled frame. A single final golden can
   miss shaking, flicker or multiple focus requests.
3. Assert the error wraps without clipping, field remains visible, draft/selection
   is retained and no repeated reveal/reset happens. Compare the visible anchor
   with a tolerance justified by expected error height or focus reveal; offset
   equality is inappropriate after legitimate extent clamping.
4. Repeat with short viewport, larger text, different error lengths, nested dialog
   and IME open/closed when affected. Synthetic insets are widget evidence only;
   execute Android IME/Next/Done/Back with native keyboard for platform acceptance.

Use bounded `pump` durations for finite transitions; `pumpAndSettle` can time out
on spinners/timers or hide extra frames. Do not swallow overflow errors or use
arbitrary long sleeps to make a flaky test pass. Stabilize the cause/fixture.

## 4. Accessibility checks

With the existing test harness, enable semantics (`tester.ensureSemantics()`;
dispose the handle via teardown) and inspect names, roles, values, selected/
disabled states and reading order. Exercise Tab/Shift+Tab, Enter/Space and Escape
with `sendKeyEvent` where supported and assert resulting focus/action.

When suitable for the target control, SDK checks include:

```dart
final semantics = tester.ensureSemantics();
addTearDown(semantics.dispose);
await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
await expectLater(tester, meetsGuideline(textContrastGuideline));
```

Place these inside a test after rendering its real controls. Apply the relevant
platform guideline, not Android touch sizing to every compact Windows control.
Automated contrast/target checks have coverage limits; inspect actual colors
including alpha/background and run native assistive technology where available.
Record tool/rules and observed scope, never equate a pass with WCAG certification.

## 5. Goldens and visual regression

- Reuse project golden infrastructure. Select a stable component/state boundary,
  deterministic data/clock/fonts/locale/theme/size/DPR and pinned SDK/platform.
- For an existing boundary, the core assertion is
  `await expectLater(finder, matchesGoldenFile('goldens/editor-error.png'));`.
  Ensure the finder resolves once and the intended `RepaintBoundary` is captured.
- Review before/after/diff images; allow only explained antialiasing/environment
  variance. Never regenerate baselines wholesale to accept a failure, use broad
  tolerance to hide regressions or assert visual quality from Ahem test glyphs.
- Goldens detect pixel changes, not correct saves, focus, semantics, IME, native
  platform overlays or user intent. Pair them with interaction/state checks.

## 6. Integration and runtime acceptance

Reuse existing `integration_test`/Driver and isolated fixtures. A suitable journey
creates synthetic data, changes the setting/field, saves, navigates to each
affected presentation, reopens and verifies the committed value. Include rejected
save/retry and unsaved Back. Restart through the existing harness to verify real
durability; rebuilding a widget with the same in-memory controller is insufficient.

Flutter integration tooling does not directly establish every native permission
dialog, notification, file picker or launcher behavior. Use available native
automation/manual steps for those cases and report missing capability. Avoid a
new testing framework when existing tooling plus focused manual evidence suffices.

For Android record emulator/device/OS, app build/profile, font scale, navigation
mode, IME and keyboard/rotation/resume observations. For Windows record build,
isolated profile, window bounds, monitor scale/DPI and mouse/keyboard observations.
Native widget painting/input/shell/menu changes retain project native Release/
self-test and manual gates. Offscreen render passes do not establish physical OS
behavior. Report executed runs separately from planned or blocked acceptance.
