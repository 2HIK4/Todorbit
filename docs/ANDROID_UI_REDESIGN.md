# Android UI and widget refinement — 2026-10-30

This work keeps the existing Flutter presentation, RemoteViews widgets, shared
repository, package identity and release infrastructure. No schema or backup
format changes, native SQLite writes, synchronization or publication.

## Design review and implementation

The thesis is a quiet, lavender productivity companion: identify the next item
and its action at a glance. Content carries the hierarchy; the accent marks an
action or calendar commitment. Remove decoration that competes with content.

Installed skills actually used: `apple-design`, `ui-ux-pro-max`,
`todorbit-ui-review`, and `todorbit-regression`. Apple references read included
accessibility, layout, typography, color, widgets, buttons, entering data,
dark mode and cross-platform translation. Transferable principles apply;
Android Material controls, Back, system time formats and 48 dp touch targets
remain authoritative. References include `layout.md` > Visual hierarchy
("Order content by relative importance") and `accessibility.md` > Vision
("Support larger text sizes"). UI UX Pro Max supplied its app quality checklist
and Flutter text-scaling guidance. Its broad design-system result included a
marketing-page structure and unrelated teal palette; those were discarded.
The verified Flutter match and mobile accessibility rules informed this work.

Existing tokens remain the source of truth:

| Role | Light | Dark | Contrast against surface, light / dark |
| --- | --- | --- | --- |
| Surface | `#FFFFFF` | `#252131` | — |
| Primary text | `#211B35` | `#F4F0FC` | 16.50 / 13.96 |
| Secondary text | `#665F78` | `#C8C0D5` | 6.05 / 8.92 |
| Accent | `#6D56BD` | `#B9A4F4` | 5.65 / 7.22 |

Native widgets use 18 sp headings, 15 sp row titles and 12 sp contextual text,
with 12 dp content gutters, 48 dp action targets and restrained rounded surfaces.
They consume both custom app palettes. Text/accent foregrounds with less than
4.5:1 surface contrast fall back to black/white. Opacity still controls the
outer shell; the inner content surface stays opaque for wallpaper-independent
legibility. No new widget settings replace existing theme/filter/opacity keys.

Compact structure: heading/date + Add; one or more fitting rows; Open/Add.
Expanded Calendar adds a three- or seven-day strip and more agenda rows.
Capacity measures bounded native text layouts against width, height and font scale, capped at 16 rows. Compact empty copy and optional date context yield to readable actions at large text sizes. Android
12+ receives exact size variants; API 26–30 receives portrait/landscape variants.
One item remains naturally sized; it is never stretched or duplicated.

## Findings and fixes

| Surface | Finding | Result |
| --- | --- | --- |
| Tasks widget | No checkbox or completion action existed | Separate 48 dp completion indicator and row target; explicit complete/reopen commands |
| Calendar widget | Add opened New Task | Dedicated Add Event route carrying the displayed date |
| Both widgets | Weak hierarchy, raw date metadata, one dimension used for capacity | Context heading, structured rows, localized dates/system 12/24-hour times, responsive capacity and overflow link |
| Expanded Calendar | Large single-item panel offered little context | Upcoming date strip with event counts and date navigation; events and sessions retain distinct identities |
| Startup/navigation | Preference loading could override a widget destination; delivery could overlap | Preferences initialize before dispatch, delivery is serialized and gated by unlock/editor state |
| Today/task lists | Generic empty instruction; weak list context | Actionable Add Task empty state, search-specific feedback, real list count/context and concise Today heading |
| Calendar | Global New Task FAB conflicted with Calendar creation; plan/session counts duplicated commitments | Calendar owns its date-aware creation controls; indicators count an explicitly scheduled task through its session and announce separate event/plan/session counts |
| Settings/About | Long ungrouped settings and no Android support action | Shared section rhythm, About and support group, visible Support and Contributors entries |
| Shared Android controls | Desktop-style 40 dp primary/outline buttons | Android 48 dp minimum buttons and icon actions; existing Windows sizing retained |

The source audit included Today, task/Inbox/Upcoming lists, task/event/session
editors, Calendar, organization, goals, habits, templates, saved views,
statistics, time tracking, drawer/bottom navigation, settings, backup/Drive,
updates, lock and contributors. Existing forms, domain calculations, empty
states and unsaved guards were reused. These screens were not independently
rebuilt. Host layout tests and rendered emulator evidence have different scopes;
verification receipts below must not be read as physical-device acceptance.

## Completion and routing boundaries

Native completion links contain an unguessable, private widget capability.
The native bridge consumes it once and returns the stable task ID, expected
UTC revision and explicit target completion state. Public links cannot choose
an arbitrary completion ID. Flutter waits for unlock and existing editors,
then calls `AppController.setComplete` / `LifeRepository.setComplete`.
Repository optimistic concurrency and recurrence rules remain authoritative.
Repeated delivery is idempotent; stale edited, deleted or archived records
cannot be silently overwritten. All widget instances refresh after publication.

Completion intentionally opens Todorbit. The existing stopped-app projection
worker is read-only and does not have a reviewed authenticated write queue.
This is the safe application-action fallback requested in the brief, not a
claim of stopped-app background completion. The checkbox never opens an editor.
Lock-enabled widgets continue hiding titles even while the app is unlocked.

Task rows retain UUIDs; events retain parent ID, displayed day and nominal
recurrence date; sessions retain their own IDs. Intent data also includes the
widget instance, separating operations without hash/request-code collisions.
The preexisting data-URI identity was already sound; no PendingIntent collision
was proven. Actual wrong-route causes were the shared Add Task link and startup
navigation race. While editing, the latest requested destination waits until
the editor closes; it does not discard a draft or open another editor over it.

## Support and Google Drive

Settings > Support Todorbit is always discoverable. GitHub-distributed builds
reuse the official `https://paypal.me/2hussam4` destination and existing optional
support dialog through the shared external-resource opener. Browser failures
remain recoverable. Windows retains its existing support destination and UI.

Google's [payments policy explanation](https://support.google.com/googleplay/android-developer/answer/10281818?hl=en-GB)
allows qualifying creator contributions without digital rewards when its stated
conditions hold. This task cannot establish the maintainer's payment eligibility.
Play and unknown distributions therefore show a non-payment Send feedback
action instead. Enabling payment links for Play needs a separate eligibility
review; no tax-exempt charity status is asserted.

Android Google Drive was already enabled (`GOOGLE_DRIVE_ANDROID_ENABLED`
defaults to true). Its OAuth, `drive.appdata` scope, snapshot encryption,
restore safety and build defaults are preserved. No OAuth JSON or credentials
were added. Real authenticated account/backup acceptance belongs to the owner.

## Verification and development artifact

| Check | Result / receipt |
| --- | --- |
| Full host gate | 426 tests pass; one intentional opt-in native-launch skip; formatting and analysis clean; release/helper Python checks and docs validation pass. `.buildlog/verify/20261030-142904-0063/` |
| Focused mobile/action/support | 42 pass. `.buildlog/verify/20261030-142420-9490/` |
| Android update UI after readable Last checked formatting | 13 pass, analysis clean, release Python 4 pass. `.buildlog/verify/20261030-150230-1152/` |
| Feature catalog helper after adding action tests | Python 8 pass; documentation links/catalog validate |
| Windows | Release build and Drive configuration gate pass; packaged companion self-test passes under explicit isolated APPDATA/LOCALAPPDATA. `.buildlog/android-ui-windows-build.log`, `.buildlog/android-ui-native-selftest.log` |
| Device integration | API 35 `TodorbitAndroidTest`, `emulator-5580`: real temporary-profile SQLite task/calendar/persistence/snapshot workflow passes. `.buildlog/android-ui-device-workflow.log` |
| Native render/capability harness | 72 cases: 180 x 180, 280 x 280, 380 x 540 dp; light/dark; 0/1/12 projection fixtures; normal/200% text; footer geometry, same-title identities, distinct widget tokens, one-use and invalid-token rejection. `.buildlog/android-ui-delivery-native.log` |
| APK | Debug GitHub build, native ELF/applicable ZIP alignment gate passes; signature matches the installed development line |

The final native-only sizing/copy refinements were verified by the native harness
and APK build after the full shared Flutter gate. Representative native renders
were visually inspected; 72 captures does not mean 72 independent manual reviews.
PNG evidence stays under `.buildlog/android-ui-redesign/native-renders-final/`.
The harness uses a native test window, restores its exact prior projection, and
removes only its reserved test keys. It does not write SQLite. Its temporary
fixture IDs are never product records.

The isolated before/after profile comparison retains all 45 table row counts,
schema 22 and stable task/event/category/project IDs. Both task completion tests
ended reopened, all three original backup files remain byte-identical, and no
reserved native fixture keys remain. The installed APK
hash matches the delivered file. See ignored `preservation.json` and
`artifact.json` beside the APK. Final live hot reload succeeds with no Flutter
runtime errors.

Actual launcher observations include retained IDs 5/6 across the upgrade,
Tasks/Calendar together, independent light/dark configuration, completion and
reopening of one of two same-title tasks, a real process-kill cold reopen, and
separate task/event editors. The completion action opened the app without an
editor. A broadcast ANR appeared during the first cold upgrade under heavy host
load; rendering/publication now use a serialized worker with receiver goAsync.
Subsequent cold action checks did not produce another Todorbit ANR. These are
observations, not startup/battery benchmarks.

Rendered app inspection covered Today, task/event editors, Calendar destination,
Settings, Support, Drive and Updates. Support handed off to Chrome's first-run
screen; no payment was attempted. Connect Google Drive reached Google's native
Checking info screen; cancellation returned the existing recoverable authorization
error. No Google account was authenticated and no cloud backup succeeded in this
session.

## Development APK and installation

- File: `.buildlog/android-ui-redesign/Todorbit-1.0.18-21-development.apk`
  (also `build/app/outputs/flutter-apk/app-github-debug.apk`).
- Package `io.github.hik4.todorbit`; version **1.0.18**, versionCode **21**.
  The established `-BuildNumber 21` override keeps Windows/pubspec versioning intact.
- Android 8/API 26 minimum, target API 36; `arm64-v8a` and `x86_64`.
- Signer `C=US, O=Android, CN=Android Debug`; SHA-1
  `64:91:E2:9F:4F:0A:0B:AB:3C:9E:48:36:11:93:F8:C5:E2:BD:E1:B7`.
- Signer SHA-256
  `9144c2df0aa461641f8570d62f880ee9e481c272a80673089a6799d111c9bf73`.
- APK SHA-256: `3a864e4900b3964245c8397f3b8677eb68548c8936555e432ed7f3439816906c`.

Update this same-signer development line with `adb install -r <APK>` or open the
APK using Android's package installer. Allow installation for that source when
Android requests it. In-place 20-to-21 installation was observed on the isolated
emulator. Do not uninstall to work around a signature mismatch on another device;
that would remove its private data. This is not production signing. No public
release, merge, push or release-tag change occurred.

Rebuild with the established Android helper and `-BuildNumber 21`. Run the native
acceptance helper documented in [Testing](TESTING.md) with the same-source APK.

## Remaining acceptance

- Launcher drag resizing was attempted; resize handles appeared, but changed
  launcher bounds were not established. Exact compact/medium/expanded native
  rendering is verified by the separate native test window.
- OEM/physical launcher behavior, reboot/launcher restart on this final source,
  API 26/33/36 and 16 KiB-page execution, physical TalkBack/RTL/rotation/keyboard
  breadth and long-run battery behavior remain manual.
- Final on-device locked/biometric, unsaved-editor rapid-tap and recurring/session
  link breadth remain manual; the relevant host guards and recurrence/identity
  tests pass. Real task/event row and cold completion paths were observed.
- Real Google account, encrypted Drive round trip/cross-client recovery, Play
  contribution eligibility and production signing remain owner acceptance.

Screenshots, logs, test archives and APKs are ignored artifacts, not Git content.
