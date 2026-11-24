# Todorbit UI Redesign 2.0 final integration

Date 2026-11-24. Branch `feature/todorbit-ui-redesign-2`. Batch 5 acceptance
`aac266d5e0240f604d043761db562eca96514c07`. Initial integration
`f17b6f8441363b71f9e142f9190059aea223681e`. Final implementation
`90768ef905d0d242301861aeaf9c76445d11bbbf`, tree
`29289383b8352b68e222f5023757638799f6c29c`.

## Source and compatibility

The Git ancestry starts at verified Beta 26 candidate
`ace8b3d25b2e760dde189cdabd7defa29035c7ea`, followed by manual-download
CI `a93e5589c867201613b9b7b87f9e13c08b9327a8` and the redesign.
Candidate is the merge base. At the implementation checkpoint the redesign
is 15 commits ahead and zero behind the candidate, and 14 ahead and zero
behind the manual-download branch. An anonymous `git ls-remote` confirmed
both tips and stable `main` at `a6d36dc7ed2863a40b7e9bc9c4cdbebc81f2c530`.
These refs require no reconciliation for this review.

Flutter 3.47.7, Dart 3.13.5, app version `1.0.19-beta.26+49`.
`pubspec.lock` SHA-256
`61d71d2387bca58943509271f8fd953a3eff733b6b4a25236208f1b9bea51fde`.
The manifest, lockfile, Gradle and signing rules, Windows runner, installer
and tracked OAuth configuration match Beta 26. The AOT/compiler inputs
include the redesigned UI and native companion paint. Android changes
cover native `RemoteViews` palette and layout and its instrumentation.
Outside the UI, the redesign projects saved-view sorting and the Calendar
agenda and serializes appearance JSON updates. The editor width is
device-local. SQLite Schema 29, repositories, backup and encryption
implementations, sync journal and wire contracts, and credential stores
match Beta 26.

| Impact | Verification boundary |
| --- | --- |
| Shared theme, shell, task lists and editors | Both platforms, high text, light/dark, palettes, action semantics, draft protection, data round trips |
| Calendar, Focus, Habits and Goals | Agenda boundaries, calendar operations, recovery, timekeeping, injected clocks, compact editing and input |
| Settings, notices, resources, conflicts and Trash | Profile reopen, sensitive recovery, export preview, confirmation and partial apply, storage boundaries |
| Windows and Android widgets | Renderer, control bounds, snapshot/command validation, packaged native companion, emulator and physical lifecycle |
| Release and storage | Schema/contract diff, synthetic upgrade and backup checks, artifact identity, installed/portable isolation, production CI and manual gates |

## Confirmed issues

- Advanced Search truncated its heading and query label at 320 dp with
  150% text and a simulated IME. The title can wrap, and the search field
  presents a short label and a separate scope hint before the filter help.
- Reset omitted inherited date bounds and the legacy non-recurring
  constraint. It now follows `TaskFilter.isActive` and clears these
  fields. Reset preserves the view name and icon. The stored filter changes
  on Update Custom View. The desktop sidebar test now checks the accepted
  `Search` field label with the same typing, clearing and dialog assertions.
- Reports keeps its help control with the title and formats the period
  and daily labels using the app's localized date helper.
- The compact settings transfer dialog uses the shared edge inset so more
  of the preview fits above its actions.
- The Windows timeline announces when an event was cancelled. The regression
  checks cancellation status, actual title-to-card contrast and the active
  event's separate appearance in light and dark.
- Compact Android widgets keep Today and the footer readable and reachable
  at enlarged text. The native test runner reports UI-thread layout failures
  while still restoring its synthetic preferences.

### Settings export/import/restart

Both Batch 5 runs ended without a verdict. The diagnostic reproduced the
stall with an instrumented copy and Flutter's 25-second test timeout.
The last markers preceded the fixture's `controller.initialize()`, before
mounting the dialog. The process still needed bounded external cleanup.
The store and Drift database had been constructed inside Flutter's fake
async test zone. The test crossed into `runAsync` to initialize that
fixture and awaited initialization which depended on futures created in
the fake zone. Same-zone fixture creation and initialization completed
the same workflow. This is a harness failure observed before product
transfer starts.

The corrected journey uses a disposable file-backed database, bounded
startup and a separate reopen after closing the original connection. It
asserts JSON export, cross-category preview, cancellation, calendar-only
apply, unchanged theme, and the persistence and JSON exclusion of the
device-local editor width. The production code correction in this dialog
is limited to compact insets.

An independently stalled theme preview/export journey used the same split-zone
fixture. Its real-async setup now also preserves the existing import, Undo/Redo,
cancel, error, reopen and close-while-exporting assertions.

## Design System 2.0 coverage

Here, **host** means Flutter or repository checks on Windows with synthetic
data, **render** means a production widget painted offscreen, and
**native** means the platform rendering path. This catalog combines
source review with applicable fresh and previously accepted evidence.
Hardware and account dependence is tracked below. See the
[67-category matrix](../.agents/skills/ultimate-ui-ux/references/problem-coverage.md),
[design rules](UI_DESIGN_SYSTEM.md), and [test ledger](TEST_RUN_LEDGER.md).

| Category | Audited behavior and evidence |
| --- | --- |
| 1. User goals and mental models | Today and Calendar separate plans, deadlines, events and actual work. Batch 1 and 3 renders and behavior. |
| 2. Workflow complexity | Create/edit opens from list, calendar and Workspace actions with one active draft. Batch 1 and 4 journeys, draft regressions. |
| 3. Information architecture | Today, Inbox, views, Calendar, Habits, Goals and Settings entry points reviewed together. Batch 1–5 shells and architecture map. |
| 4. Discoverability | Quick and advanced search, list overflow controls, timer actions. Checked their labels, visible actions and compact placement. |
| 5. Onboarding | Existing support intro and first-launch prompts reviewed by source and startup checks. In-person first-run remains manual. |
| 6. Cognitive load | Today lists, progressive search, Sync summaries and report hierarchy reviewed in representative populated renders. |
| 7. Labels and copy | Search scope and reset, planned vs deadline, portable settings, pending sync and Shared Files retention reviewed. |
| 8. Navigation | Windows sidebar, Android navigation/drawer, nested editors and Settings routing. Host draft and mobile checks. |
| 9. User control | Dismiss, discard, save, undo, appearance and choice of home, list and detail arrangements. Host and acceptance renders. |
| 10. Trust | Destructive actions, data scope, conflict previews, lock and local storage distinctions checked against behavior. |
| 11. Hierarchy | Today, task/event editor, Habit/Goal, Settings, Focus and report title/action hierarchy inspected in renders. |
| 12. Typography | Windows and simulated Android font selection, enlarged input text and title wrapping. New Search capture. |
| 13. Spacing | Shared spacing in shell, task density, dividers and dialogs. Compact transfer dialog adjusts its outer inset. |
| 14. Geometry | Bounded task lists, focused editor at narrow widths, month grid and responsive report title. Host and render evidence. |
| 15. Color and contrast | Semantic neutral/teal default, selected/error/disabled states, contrast validation and native fallback colors. |
| 16. Themes | Both themes, high-contrast validation and custom palette behavior. Batch evidence and host theme/preference checks. |
| 17. Icons | Task list quick actions, filter and info controls use aligned text, tooltip or semantic labels. Physical assistive checks pending. |
| 18. Surfaces | Shared rows, dividers and settings groups reviewed. Report metric cards keep an explicit metric grouping. |
| 19. Density | Bounded Windows content and Android long titles, muted metadata, empty lists and navigation at 150%. |
| 20. Design system | Batch surfaces compared to shared tokens and controls. Changes keep the same architecture and default colors. |
| 21. Actions | Selectors, task completion, timer, Save, Cancel, Reset and destructive confirmations checked at relevant entry points. |
| 22. Forms | Task, event, habit, goal, privacy and advanced query inputs tested with high text or simulated insets. |
| 23. Validation | Invalid inputs, form cancellation, malformed backup/encryption/settings, and no reset on corruption covered by host tests. |
| 24. Dependent inputs | Category/project, dates, recurrence, notification schedule and import category selection reviewed. |
| 25. Menus and selections | Keyboard-accessible anchored selectors, list actions, view mode and theme/configuration options reviewed. |
| 26. Dialogs | Editors, Settings transfer, permission/error/recovery dialogs and focused presentation. Host and offscreen evidence. |
| 27. Scroll and stability | Lazy lists, focus and report scrolling, month agenda, reachable dialog actions and high-text controls. |
| 28. Focus and keyboard | Tab/select and Escape/cancel behavior, focus restoration, draft prompts and simulated IME. Physical input pending. |
| 29. Feedback | Save, zero matches, sync backlog, last success, recovery/error and transfer progress reviewed. |
| 30. Loading, empty and offline | Empty Inbox/Calendar/Goals/reports, offline/pending/error sync, disabled native capability and recovery. |
| 31. Selection and drag | Bulk task actions, calendar event moves and resizes with recurrence and Undo/Redo. Physical gestures pending. |
| 32. Search, filter and sort | Quick and advanced entry points, grouped options, inherited filters, saved sorting and reset with icon preservation. |
| 33. Collections | Today/Inbox/All, status/date lists, categories, projects, reports and archives. High-text and dense examples inspected. |
| 34. Calendars | Day, Week, Month and compact agenda. Start/end day projection, recurring moves, fixed events, planned sessions and history. |
| 35. Productivity | Task edit/complete, Focus/timers, check-ins, goals and progress. Earlier accepted renders and behavioral checks. |
| 36. Responsive | Windows 800–1440 dp and Android 320–390 dp samples, 100%/150%, compact form controls and insets. |
| 37. Mobile | Android Back, drawer, navigation destinations, touch targets and simulated keyboard. Launcher/touch/IME device checks pending. |
| 38. Desktop | Sidebar resize, editor presentation, keyboard and pointer affordances and Windows widget companion. Physical DPI pending. |
| 39. Web | Outside supported product targets. |
| 40. Alternative input | Tooltips, Escape, focus, tap reachability and keyboard-driven test cases. Physical keyboard, mouse and touch follow-up. |
| 41. Visual accessibility | Contrast, text scaling, wrapping, scroll, palette validation and non-color status labels. |
| 42. Assistive semantics | Named actionable controls, form labels, timer/completion states, native tap bounds. Narrator and TalkBack manual. |
| 43. Locale and RTL | Local date labels, calendar week start and existing RTL layouts. Complete translation coverage is outside this checkpoint. |
| 44. Motion | Shared reduced-motion settings and conditional transition paths reviewed. System behavior on devices pending. |
| 45. Widgets | Windows native production renderer, Android RemoteViews and action-token checks. Real launcher/Explorer behavior pending. |
| 46. Notifications | Windows settings render, native capability message and scheduling/opt-in host checks. Actual alarms require device runs. |
| 47. UI state | Route migration, editor dirty-state protection, local timer updates and cache invalidation verified by relevant test groups. |
| 48. Personalization | Palette, navigation, row preferences, panel width and restart, portable inclusion and local exclusion. |
| 49. Synchronization | Offline UI, pending count, last successful sync, fake-device exchange tests and source contract diff. Real accounts pending. |
| 50. Conflicts | Conflicts dialog and durable recovery checks with synthetic records. Real concurrent device resolution awaits acceptance. |
| 51. Offline | Network failure, pending and offline restore/recovery messaging. Mock transport and local-first persistence. |
| 52. Delete and recovery | Task completion/deletion, Archive/Trash, restore, destructive confirm and calendar undo/redo. |
| 53. Backup and transfer | Database snapshot, restore/reopen and Settings JSON with cancel, scoped apply and persisted restart. |
| 54. Privacy | PIN and hidden counts, app-lock projection, backup key boundaries, redaction and package secret checks. |
| 55. Accounts | Sync status and account/vault handling with fakes. Real sign-in, recovery and revocation remain required manual acceptance. |
| 56. Responsiveness | Host benchmark, collection/route source checks and platform startup observations reported separately. |
| 57. Failure recovery | Settings harness isolated. Corrupt profile and interrupted restore fail closed with actionable outcome. |
| 58. Updates and compatibility | Beta 26 lineage and config diff, schema 29 smoke tests, update validation and candidate upgrade gates. |
| 59. Stress behavior | Large-list and calendar fixtures, enlarged text, long titles, empty and populated views, widget render matrix. |
| 60. Multiple instances | Source preserves instance/profile scope. Windows installed/portable, companion collision and process isolation are system checks. |
| 61. Platform integrations | Android Shared Files/storage and Windows resource launch, notifications, native widget actions and safe update boundaries. |
| 62. Dates and measurements | Local date/time and report labels, planned dates vs deadlines and actual work, timer units and recurrence. |
| 63. Error recovery | Settings, Sync, startup, backup and update errors retain retry, recovery paths and data. |
| 64. Background operations | Timer/recovery tests and sync job semantics. Real Doze, lifecycle and long-run delivery require device acceptance. |
| 65. Respectful design | Opt-in notifications, lock scope, local-first defaults, storage disclosure and user-controlled customization. |
| 66. AI workflow | Actual captures, no cosmetic redesign, preserved accepted evidence with scoped corrections and exact-source receipts. |
| 67. Verification | Reproduced harness stall, preserved assertions, measured render reachability, separate host/native/device claims and gates. |

## Captures

Fresh offscreen production Flutter captures with Segoe UI and Roboto are in
`C:/Users/User/Documents/Codex/Todorbit-final-integration-renders`.

| File | Scenario |
| --- | --- |
| `windows-search-light.png` | 1280×800, 100%, populated advanced search |
| `android-search-dark-150-ime.png` | 320×740, 150%, simulated 260 dp keyboard, reachable query and actions |
| `windows-reports-dark-150.png` | 800×740, 150%, populated report |
| `android-reports-light-150.png` | 320×740, 150%, empty report |
| `windows-notifications-light-150.png` | 800×740, 150%, unavailable companion |
| `android-settings-transfer-dark-150.png` | 320×740, 150%, portable settings actions |

The earlier Batch 1–5 render and native locations are in the
[test ledger](TEST_RUN_LEDGER.md). Their unchanged surfaces were
rechecked by sampling accepted screenshots alongside these new captures.

## Regression evidence

The 55-minute serial run of the initial integration source reported 1,211
passes, 25 fails and 9 opt-in skips. The stalled theme journey and the
following transfer journey in that file were separately reported incomplete
after its verified test worker was stopped. This remains an initial failing
run. The corrected cases were run separately with the assertions intact.

| Scope | Verified result |
| --- | --- |
| Settings and appearance | 18 focused cases passed. The repaired Settings restart and theme journeys also passed in the final-source group. |
| Search, saved views and draft navigation | 57 cases passed before the final spacing correction. The exact-layout render run passed 7 cases, and the final group repeated draft protection. |
| Windows startup, resources and database crash safety | 37 passed with an explicit pinned Dart path and opted-in disposable application-data directories. This group includes the opt-in journeys and all six creation/upgrade interruption cases that initially lacked a callable Dart worker. |
| Calendar and contemporary presentations | 34 corrected audit/layout cases passed. The revision uses real rendered geometry, contrast and current actions. Five populated Calendar/Trash/transfer cases passed in the earlier correction run. The existing resize, undo and recurrence cases passed with an explicit Windows fixture. |
| Event color and secondary surfaces | 39 passed, covering color persistence, advanced search, reports, resource-adjacent views, history, notifications, updates and Settings. |
| Contrast and Sync interruption | 22 passed, including the inherited color's visible icon and all four real worker-death cases with the pinned Dart path. |
| Final committed source | 46 focused cases passed, covering cancellation semantics, both transfer journeys, draft safety and Android host contracts. All affected Dart paths analyzed cleanly. 39 architecture checks, documentation routing and diff checks passed. |

The baseline run also exercised task and calendar CRUD, categories/projects,
recurrence and Undo/Redo, timekeeping and recovery, Habits and Goals, sync
conflicts and offline exchange, backups and encryption, and platform contracts.
Its unchanged passing cases and source-equivalent evidence from Batches 1–5
remain applicable. The test ledger records groups and source identities.
An exact-candidate, single green CI run is still due. [Test run ledger](TEST_RUN_LEDGER.md)

## Windows Release, normal-session runtime and data

Windows Release compiled and the repository's package tools produced a
portable ZIP and an Inno Setup 7.1.0 installer. CRT verification checked
three Microsoft-signed x64 DLLs. Both packages used the tracked disabled
Drive fixture. The production OAuth guard rejected the disabled fixture
as designed. The repository-pinned compiler was extracted in portable mode
to the ignored verification directory.

A scratch build repaired two toolchain setup problems. Validated NTFS
junctions supplied the pinned Windows package links when the host lacked
symlink privileges. Removing inherited indexed Git config from the build
process fixed MSBuild's empty-value handoff. The final Windows release
bundle used the initial source export plus a byte-matched final timeline
file. The packaged companion self-test passed. Its executable SHA-256
`7ca60360d9124e5b8990c3e534e3268fe46eb60796adfe1a5bff31b5b8f72b9e`
matches the final ZIP member.

Normal Windows runtime used a portable executable in the development
worktree with child-only APPDATA and LOCALAPPDATA. The older Beta 26 source
build created an intact Schema 29 profile. The redesigned package reopened
that profile and retained its synthetic task and device-local task detail
preference. The main process and companion were identified by their
disposable executable path. Before reopen, the fixture omitted the
launch-at-sign-in setting to keep Windows startup registration outside
the exercise.

The first launch's visible-window probe timed out because it used a hidden
launch. SQLite and profile checks verified the initialized profile. On
the redesigned launch, the native Flutter HWND appeared after 432 ms.
At 4.44 s, working set was 200 MiB and accumulated process CPU was 3.94 s.
The HWND remained hidden, so this is a process and storage sample. The
earlier Windows Sandbox run preceded the updated policy and is excluded
from this acceptance.

The rebuilt artifacts and checksums are in
`.buildlog/ui-redesign/final-rebuilt-windows-artifacts/`. The Beta 26 source
bundle is in `.buildlog/ui-redesign/beta26-rebuilt-windows-artifacts/`.
Normal runtime evidence is in `final-windows-normal-context.json`,
`final-windows-normal-process.jsonl` and `final-windows-normal-data.log` under
`.buildlog/ui-redesign/`. [Inno Setup vendor documentation](https://jrsoftware.org/inno-setup/documentation/topic_technotes.htm)

## Android build and runtime

The supported Android Release script built the arm64/x64 GitHub APK with
the unchanged version, Drive disabled and an ephemeral local signing key.
`apksigner` verified the signature, and the artifact verifier checked ELF
and APK ZIP alignment on eight native libraries. The resulting APK SHA-256
is `7c907be867d80b5b85ad9b82b11ad44899924556ab0777f98465278ce038763c`.
The local artifact is under
`.buildlog/ui-redesign/final-android-release-artifacts/`.

API 35 x86_64 emulator testing used 4 KiB pages and a separate Debug package.
The initial APK passed alignment on seven native libraries. Shared Files
passed four native storage/sharing assertions on both initial and corrected
widget builds. The 320 dp, 150% real emulator showed Today and the Create
form with the Android keyboard and Create action visible together. Touch and
IME input saved a synthetic task. Returning from Home brought the app to
the foreground in 605 and 846 ms in the two Debug runs. One in-place Debug
install was rejected as expected because the fixtures used different
development signatures. The emulator profile was retained.

The native stress matrix reported 192 cases passed across Tasks and Calendar,
light/dark, 100%/200% text, 420/560 dpi, four widget sizes and three row counts.
It checked geometry, 48 dp actions and one-use command tokens. Earlier runs
exposed the clipped 180 dp Today label and a 280 dp footer below 48 dp.
The final padding and short empty labels passed the full matrix, including
the higher density that still clipped the interim fix.

Inspect `android-runtime-debug-delayed.png`, `android-runtime-create.png`
and `android-runtime-create-ime.png` in the capture directory. A separate
`native-android/` subdirectory contains four widget-local captures and
`footer-bounds.json`. The 180 and 280 dp corrected frames were visually
inspected. `android-runtime-debug-320-150.png` is the earlier delayed splash
diagnostic. Native logs and UI hierarchy assertions are under
`.buildlog/ui-redesign/final-android-runtime/`.

## Performance and resource scope

The 15-scenario Flutter host benchmark passed. Selected measurements were
331 ms for controller initialization, 2.79 s for first test frame, 1.27 s
for next-month navigation and 75 ms for the long-list scroll probe. Process
RSS was 261 MiB initially, 415 MiB idle and 431 MiB after extended simulated
navigation. These are host-test measurements under concurrent work.

Today uses lazy Sliver lists and Android lists use lazy builders. The compact
timer ticks locally and cancels on disposal. The existing Focus screen
rebuilds while a timer is running at 250 ms intervals. The timed refresh
and disposal paths were reviewed. Device release frame and long-run memory
profiles remain unqualified.

Under contention, the Debug Android emulator's system log recorded first
MainActivity display at 49.28 s and 67.54 s after the initial ADB wait
timed out. The initial pre-frame PSS sample was 66.3 MiB. These measurements
flag a need for a controlled Release startup check. The installed
production artifact and OEM background delivery were outside the sample.

## Remaining acceptance and decision

The branch can enter separately authorized release preparation. Beta approval
still depends on the following gates.

| Classification | Remaining evidence |
| --- | --- |
| Release blocker | Run exact-candidate CI with the pinned toolchain and retain a green serial suite, production Windows config receipt and production-signed Android package. Compare signer, version, artifact digests and updater selection against the reviewed candidate. |
| Release blocker | Run the official 16 KiB API 36 runtime gate on the release candidate. Exercise install, task/event persistence, background/foreground and native boundaries on that emulator. Record Release startup and foreground return under controlled load. |
| Required manual acceptance | Use a separate Windows test account or test machine for the registered installer and update. Seed a disposable older installation, apply the reviewed installer/update, reopen the task and preference, then check rollback/reinstall and profile retention. The normal-session portable reopen already covers Schema 29 data. |
| Required manual acceptance | In a disposable Windows profile, use Tab, Enter, Escape, the mouse and Narrator at regular and enlarged system text/DPI. Check editor drafts, calendar drag/undo, notification activation and the widget's Explorer attachment. Verify assistive output and physical interactions that the automated probes cannot observe. |
| Required manual acceptance | With separately authorized test accounts and a disposable Drive workspace, pair two clients, edit conflicting records offline, reconnect, resolve and reopen. Verify independent snapshot restore plus Standard and Private sync recovery, including the recovery code only for the Private workspace. |
| Required manual acceptance | If a distribution target needs OEM-specific delivery evidence, place its native widget, schedule a synthetic alarm, leave the app and let the target enter idle, then verify delivery, task state and widget refresh after waking. Routine Android checks stay on the emulator. |
| Nonblocking deferred improvement | Measure long-running Focus rebuild cost and extended memory on the target release build. The current host sample is suitable for comparison under matching conditions. |

Schema, sync journal, backup/encryption contracts and version stayed at the
reviewed baseline. All execution used disposable data or mocked services.
