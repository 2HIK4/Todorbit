# UIUX-02 independent review and repair — 2026-11-15

## Verdict and identity

**APPROVED WITH LIMITATIONS AFTER REPAIRS** for the scoped source and host-rendered
UI work. This does not approve Gemini's product-wide audit claim, an installed
Android upgrade, physical launcher behavior or a release.

Branch `codex/independent-beta-review`, HEAD
`61bde1c54c01d6d3f55dbc8b9a4585712cdf9750`, retained throughout. Product/test/
configuration/skill fingerprint: `f6bb882b59dac7b458c8c5e3080ee8daa910534cac565614e016cf03838d407a`. See the
[source manifest](UIUX02_REVIEW_SOURCE_MANIFEST_2026_11_15.json).
No commit, push, merge, version change, publication or release was performed.
Unrelated untracked STORAGE_CLEANUP_2026_11_04.md, STORAGE_MAINTENANCE.md and
TODORBIT_MODULAR_ARCHITECTURE_AUDIT.md were preserved.

## Findings and resulting behavior

1. **Receiver exposure:** Gemini exported SurfaceRefreshReceiver without checking
   actions. Any external explicit broadcast could enqueue widget refresh,
   reminder rescheduling and background jobs. The receiver is private again and
   rejects null/unknown actions before goAsync. Midnight now refreshes widgets
   without starting reminder/Sync jobs. An intent filter is not access control.
2. **Pinned Today:** selecting Today's cell previously stored a concrete date.
   It could remain pinned until projection bounds rejected it. Today now removes
   the override. Deliberate past/future browsing stays selected across rollover
   and resume; Back to today restores following. No expiry interrupts active
   browsing, and legacy selections are preserved because their intent is unknown.
   IDs and settings remain per widget; no SQLite or Sync data changed.
3. **Mobile lifecycle:** added a disposable foreground civil-midnight timer as
   well as resume reconciliation. Today indicators update even while browsing;
   only Follow Today moves selection. Date-picker selection now explicitly sets
   that mode. Normal tab entry clears stale deep-link context; a fresh deep link
   still selects its requested date. Observer/timer are removed on disposal and
   the timer is cancelled outside resumed state.
4. **UI:** retained alarm field spacing/helper styling and occurrence-action
   grouping; made organization layout consider text scale; corrected misleading
   “all occurrences” copy to “Use as series alarm” with override-preserving
   semantics. Save handlers, recurrence mathematics and alarm persistence remain
   unchanged. Task-editor Dart formatting accounts for much of its large diff.
5. **Rendered defects:** mode labels and month/date headings broke words at
   320dp/2×. Controls now wrap, the month title separates from navigation, and
   Back to today moves below a date heading when space is insufficient. The
   empty-guidance text measured about 1.3187:1 against the light background;
   it now uses onSurfaceVariant and its contrast test passes.
6. **Card scope:** reverted global CardTheme clipping. Mobile agenda cards and
   the desktop agenda card clip locally; rounded selection remains shaped.
   Menus use Navigator overlays, captured separately from page-only boundaries.
   Desktop card behavior has source/analyzer evidence, not desktop runtime proof.

The UX necessity review favored one explicit Today action, ordinary responsive
composition and truthful save/series wording. It preserved advanced recurrence,
resources/checklist immediate persistence, explicit task Save and existing theme
roles. No unrelated screen redesign was undertaken.

## Android platform/security assessment

Current manifest actions are BOOT_COMPLETED, MY_PACKAGE_REPLACED, TIME_SET,
TIMEZONE_CHANGED, LOCALE_CHANGED and SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED.
The only additional accepted action is the private `midnight` alarm. It uses an
explicit SurfaceRefreshReceiver target, request code 0 and UPDATE_CURRENT plus
IMMUTABLE; identity is unchanged from older APKs. Widget-date PendingIntents still
explicitly target the private TasksWidget/CalendarWidget providers, with widget
ID/date in identity. Activity navigation retains its explicit MainActivity target.

All listed framework actions, plus the removed DATE_CHANGED action, are protected
system broadcasts in the [AOSP manifest](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/main/core/res/AndroidManifest.xml).
Custom `midnight` and arbitrary action strings are not protected; non-exported
access control is therefore essential. No external data/command extras are
forwarded to the refresh work. Framework delivery to a non-exported receiver is
supported by [receiver semantics](https://developer.android.com/guide/topics/manifest/receiver-element).
The [security guidance](https://developer.android.com/privacy-and-security/risks/insecure-broadcast-receiver)
supports removing accidental exposure.

Actual min/target SDK: 26/36. Boot, clock, zone and locale are documented
[implicit-broadcast exceptions](https://developer.android.com/develop/background-work/background-tasks/broadcasts/broadcast-exceptions).
Own-package replacement is addressed to the affected app; the exact-alarm grant
broadcast has its platform-specific manifest delivery behavior. DATE_CHANGED is
not in the documented exception list, so it is not the rollover dependency and
its added manifest registration was removed. Exporting a receiver does not
bypass implicit-broadcast restrictions. AOSP Android 16 AlarmManagerService's
DATE_CHANGED construction was additionally read from its official source; no
claim about every OEM sender/flag follows from the exception list alone.

The [AlarmManager contract](https://developer.android.com/reference/android/app/AlarmManager#setAndAllowWhileIdle(int,%20long,%20android.app.PendingIntent))
allows idle delivery but keeps batching, throttling and possible delay. This is
not exact-midnight scheduling. One shared inexact wakeup alarm is retained only
while Tasks/Calendar widgets exist; repeated scheduling replaces it. Last-widget
deletion cancels it. Creation/configuration, boot after unlock, own-package
replacement, clock/zone change and activity start rearm it in current local time.
Civil-midnight calculations cover 23/25-hour DST days. No new special permission.
App restrictions, force-stop, pre-unlock credential storage and OEM policies can
still prevent/delay work; opening the app reconciles. Rendering recalculates local
Today from the clock. Projection contents remain bounded snapshots, not invented
future data. A once-daily wakeup for installed widgets is the chosen bounded cost.

Provider class names, application ID, XML, preferences file and retained config
keys were not renamed. Static upgrade compatibility is intact; actual installed
ID/config/navigation/content/alarm preservation remains untested. No running
disposable emulator was available (`adb devices -l` empty), no suitable installed
source-compatible candidate was established, and no APK build/install or personal
AVD/account was used just to make an upgrade claim.

## Rendered evidence and display configurations

**2 application screens rendered:** Mobile Calendar and Task details; isolated
AlarmField is a third representative surface. **24 final PNGs were inspected**
from the following missing-case matrix. Four captures per configuration show
Calendar Today, Calendar browsing, alarm options and task organization/occurrence
sections. Default layouts have readable hierarchy, separated controls and
consistent spacing. Stress layouts use additional rows/scrolling and retain text
scaling. A scrolled image may show content entering/leaving the viewport; this is
not a claim that all editor sections fit simultaneously.

| Purpose | Logical viewport | DPR | Flutter TextScaler | Theme | Locale |
| --- | --- | --- | --- | --- | --- |
| Normal appearance | 360×800 | 1.0 | no scaling / 1.0× | Light | en-US |
| Normal appearance | 393×852 | 1.0 | no scaling / 1.0× | Light | en-US |
| Normal appearance | 360×800 | 1.0 | no scaling / 1.0× | Dark | en-US |
| Normal appearance | 393×852 | 1.0 | no scaling / 1.0× | Dark | en-US |
| Accessibility stress | 393×852 | 1.0 | TextScaler.linear(1.5) | Dark | en-US |
| Accessibility stress | 320×850 | 1.0 | TextScaler.linear(2.0) | Dark | en-US |

Final cases load Flutter's bundled roboto-regular.ttf and MaterialIcons. These
are Android-themed offscreen Flutter tests, not actual Android screenshots,
nonlinear OS accessibility text, IME/status/navigation bars or OEM font metrics.
Each PNG has a sibling JSON with observed MediaQuery size/DPR, effective scale,
brightness, locale and font source. All 48 capture identities/configurations and
SHA-256s are recorded in the [screenshot manifest](UIUX02_SCREENSHOT_MANIFEST_2026_11_15.json).

Earlier 24 captures: light theme, en-US, DPR 1; alarm/Calendar 320×850/1×,
390×850/1× and 320×850/2×; task organization 420×900/1×, 320×900/1× and
390×900/2×, with remaining editor sections at 390×900/2×. These used Segoe UI
substituted as Roboto, and are historical stress/interaction evidence. Their
metadata was reconstructed explicitly from the executed fixture settings, not
misrepresented as newly measured telemetry. Final Roboto cases supersede normal
appearance claims. Original image files A/B/C were not attached; their written
symptoms guided this scoped review.

Representative final images (local ignored evidence, not committed artifacts):

| Configuration | Calendar | Alarm options | Task details |
| --- | --- | --- | --- |
| Dark 393dp / 1× | [PNG](../.buildlog/uiux02-review/normal-calendar-393x852-1.0-dark.png) | [PNG](../.buildlog/uiux02-review/normal-alarm-393x852-1.0-dark.png) | [PNG](../.buildlog/uiux02-review/normal-task-393x852-1.0-dark.png) |
| Light 360dp / 1× | [PNG](../.buildlog/uiux02-review/normal-calendar-360x800-1.0-light.png) | [PNG](../.buildlog/uiux02-review/normal-alarm-360x800-1.0-light.png) | [PNG](../.buildlog/uiux02-review/normal-task-360x800-1.0-light.png) |
| Dark 393dp / 1.5× | [PNG](../.buildlog/uiux02-review/normal-calendar-393x852-1.5-dark.png) | [PNG](../.buildlog/uiux02-review/normal-alarm-393x852-1.5-dark.png) | [PNG](../.buildlog/uiux02-review/normal-task-393x852-1.5-dark.png) |
| Dark 320dp / 2× | [Browsing PNG](../.buildlog/uiux02-review/selected-calendar-320x850-2.0-dark.png) | [PNG](../.buildlog/uiux02-review/normal-alarm-320x850-2.0-dark.png) | [PNG](../.buildlog/uiux02-review/normal-task-320x850-2.0-dark.png) |

The corrected [inventory](UIUX_COMPREHENSIVE_AUDIT_2026_11_15.md) classifies all
24 original categories. No “Healthy” status or 24×11 approval remains.

## Verification invocations and evidence reuse

Commands below ran on the existing Windows host/Flutter toolchain with disposable
in-memory SQLite and temporary preferences. Logs are local under
`.buildlog/uiux02-review/`. Times below are log-completion times on 2026-11-15,
UTC+03:00. No personal profile was launched. Baseline/failed logs are retained.

`F` = `flutter test --no-pub --concurrency=1`.
`G` = `./gradlew.bat :app:testGithubDebugUnitTest --tests io.github.hik4.todorbit.SurfaceRefreshPolicyTest -Ptarget-platform=android-x64 --no-daemon --max-workers=2 '-Dorg.gradle.jvmargs=-Xmx2G -XX:MaxMetaspaceSize=1G -XX:ReservedCodeCacheSize=256m'`,
from android/, JAVA_HOME set to the installed JDK 21.0.8.
`A` = `flutter analyze --no-pub --no-fatal-infos`.

| Completion | Invocation / log | Result and reason |
| --- | --- | --- |
| 09:43:49 +03:00 | `Gradle offline default targets (after failed redirection/JAVA_HOME preflight attempts)`; `native-before.log` | Blocked: uncached arm32 Flutter artifact; narrowed to actual x64 target. |
| 09:46:42 +03:00 | `G --offline`; `native-before-x64.log` | Blocked at unit-test dependency resolution: uncached JUnit; Kotlin app compilation completed. Existing dependency downloaded on justified retry. |
| 09:45:17 +03:00 | `python .buildlog/uiux02-review/check_receiver.py`; `manifest-before.log` | Expected FAIL: receiver exported. Earlier one-line PowerShell quoting attempt did not run Python. After repair same assertion PASS. |
| 09:49:27 +03:00 | `G`; `native-final.log` | PASS, Kotlin compilation and 4/4 JVM security/action/DST/date-policy tests; XML copied to native-tests.xml. |
| 09:50:39 +03:00 | `F test/mobile_calendar_date_following_test.dart test/task_editor_ui_polish_test.dart test/alarm_field_test.dart`; `flutter-first.log` | 9 pass / 1 fixture failure: draft assertion queried an offscreen title. Two AlarmField tests pass and are retained. |
| 09:52:10 +03:00 | `F test/mobile_calendar_date_following_test.dart --plain-name 'Calendar reflows and selected/pressed cards stay rounded'`; `calendar-large-before.log` | Expected FAIL: Week split into two lines at 320dp/2×. Pre-fix screenshot and assertion retained. |
| 09:53:58 +03:00 | `F test/mobile_calendar_date_following_test.dart test/task_editor_ui_polish_test.dart test/task_editor_schedule_layout_test.dart`; `flutter-final.log` | PASS 10/10 after responsive mode repair/fixture correction; schedule test not repeated subsequently. |
| 09:55:35 +03:00 | `F test/mobile_calendar_date_following_test.dart test/task_editor_ui_polish_test.dart`; `flutter-interactions.log` | 8 pass / 1 fixture failure: checkbox offscreen; Calendar selected screenshot exposed date-heading fragmentation. Menu captures initially omitted Navigator overlay. |
| 09:57:41 +03:00 | `F test/mobile_calendar_date_following_test.dart test/task_editor_ui_polish_test.dart`; `flutter-interactions-final.log` | PASS 9/9 after date-header composition, full-overlay captures and hit-target correction. |
| 09:59:54 +03:00 | `F test/mobile_calendar_date_following_test.dart --plain-name 'Calendar empty guidance has readable text contrast'`; `contrast-before.log` | Expected FAIL: actual contrast 1.318696653; changed text role, not test threshold. |
| 09:59:35 +03:00 | `A calendar_view.dart, mobile_calendar.dart, mobile_workspace.dart, alarm_field.dart, task_editor.dart and both review tests/capture helper (full lib/features and test paths)`; `analysis.log` | PASS: no errors/warnings, two pre-existing missing-braces style infos. 64.3s. |
| 10:02:08 +03:00 | `F test/mobile_calendar_date_following_test.dart test/task_editor_ui_polish_test.dart --name 'review display configurations|Calendar empty guidance'`; `display-configurations.log` | FAIL: matrix helper disposed its ProviderScope then reused the controller. Fixed explicit per-test container ownership; no production reset/failure suppression. |
| 10:03:36 +03:00 | `F test/mobile_calendar_date_following_test.dart test/task_editor_ui_polish_test.dart --name 'review display configurations|Calendar empty guidance'`; `display-configurations-final.log` | PASS 3/3, six missing display configurations / 24 inspected PNGs plus contrast regression. |
| 10:06:44 +03:00 | `A lib/features/mobile/mobile_calendar.dart test/mobile_calendar_date_following_test.dart test/task_editor_ui_polish_test.dart test/support/uiux_review_capture.dart`; `analysis-final.log` | PASS, no issues, 14.5s; only files changed since prior analysis. |
| 09:57:15 +03:00 | `dart format changed Dart files; formatter iterations logged as format*.log`; `format-final.log` | PASS; final changed-file formatting and whitespace check also recorded at completion. |

There were **15 distinct Flutter tests passing across scoped invocations**, plus
**4 JVM tests**. This was not one final 15-test/full-suite invocation. Later
visual-only text-token/layout and test metadata/container changes are identified
above; their new/missing cases were run, rather than repeating unaffected clock,
alarm, schedule or native checks. Early fixture failures were diagnosed, not
suppressed: title scrolled offscreen, label-edge/checkbox input not hit-testable,
and a provider reused after its owning scope disposed it. Input targets and
explicit per-test ProviderContainer lifetime were corrected. Later display cases
passed with actual Roboto.

Gemini's 3/2/23/1/2 counts lack source-compatible receipts and are not counted as
independent passes. Existing data/Sync/recurrence/native-Windows evidence is not
rerun or relabeled: those implementation boundaries are unchanged. Source
fingerprints are final review identities; earlier commands' exact intermediate
byte manifests were not captured, and their logs must not be described as passes
on every final byte. Final source matches the final three missing-case tests and
scoped analyzer; native source predates the successful compiled classes and its
four-test XML receipt.

## Skills and remaining acceptance

Only the three already modified references were refined. Removed universal
exported-receiver/mandatory-idle-alarm/manual-expiry rules; bounded scheduling and
sender/SDK/security checks now replace them. Removed arbitrary 48–64dp footer
requirements and global clipping prescriptions. Added mode-consistent date-picker
handling and evidence-based local interaction checks. SKILL.md/frontmatter are
unchanged from HEAD; root AGENTS.md routes both Gemini and Codex to the canonical
skills. Existing relative references remain discoverable. The official
quick_validate.py could not import PyYAML in either available Python; no package
was installed just for validation. Unchanged entrypoints and changed local links
were checked separately; this is not a claimed official-validator pass.

No known scoped code-review blocker remains. Release/platform blockers remain
explicit in [deferred verification](DEFERRED_VERIFICATION.md): physical overnight
Doze/reboot/clock/zone behavior (DEF-AND-WIDGET-DOZE), actual in-place installed
upgrade (DEF-AND-WIDGET-UPGRADE), and real Android nonlinear fonts/IME/insets/
TalkBack/locale plus affected Windows input/visual acceptance (DEF-UIUX02-DEVICE).
DTD discovery found no debug app; requested hot reload was attempted and returned
no connected DTD/app, not a runtime pass. Broader existing release gates remain
open. No Windows build, full Android release build or unrelated full suite ran.

## Completion checks and final Git status

- `dart format --output=none --set-exit-if-changed` on the seven edited/new
  mobile/shared/editor/test files: PASS, zero changes (`format-check.log`).
  The one-line desktop agenda clip insertion retains surrounding baseline format.
- `python tools/dev/check-docs.py` on the seven changed review/tracking Markdown
  documents plus canonical skill entrypoints/changed references: first failed on
  newly written Windows-encoded punctuation. Normalized only those invalid bytes
  to UTF-8; rerun PASS, zero broken local links/catalog errors
  (`docs-check.log`, `docs-check-final.log`). No runtime source was changed.
- `quick_validate.py` for each canonical skill: BLOCKED by missing `yaml`;
  Python 3.13 probe also lacked it. No official validator pass claimed.
  Both unchanged SKILL.md/frontmatter contents were independently compared to HEAD.
- Optional contact-sheet generation lacked Pillow; no images were altered.
  Final 24 PNGs were instead inspected individually with the image viewer.
- Final source/config/test hashes and all 48 screenshot/configuration hashes were
  checked against their manifests. `git diff --check` PASS. Runtime and
  whitespace-insensitive diffs were reviewed; unrelated work remains intact.
- Final working tree: **16 modified tracked paths, 12 untracked paths** (including
  the three pre-existing unrelated documents), **nothing staged**. Branch and
  HEAD remain unchanged. Generated logs/PNGs stay ignored under .buildlog.

The final whitespace gate initially exposed CRCRLF line endings introduced by
the documentation encoding repair. Normalized only changed review documents
to UTF-8/LF and reran the whitespace/local-link checks. Runtime source and
source/screenshot hashes were unchanged.
