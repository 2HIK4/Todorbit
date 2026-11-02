# Todorbit UI hierarchy review - 2026-11-02

Candidate: `1.0.19-beta.5+28`, branch `feature/ui-hierarchy-polish`, baseline
`aae8928` (published runtime `67b265d`). Release gates are pending until recorded
below. This receipt distinguishes source review, offscreen render and live app
observations; it does not certify every screen or physical Windows/Android input.

## Design direction and findings

Todorbit is a quiet lavender planner. The next item and its action should be
recognizable before descriptions or implementation details. Existing Material
and Fluent interaction, custom themes and familiar navigation stay authoritative.

| Priority | Finding | Implemented response |
| --- | --- | --- |
| P0 | Mobile event color field overflowed under production typography | Flexible selected/menu labels preserve the swatch, arrow and readable choice |
| P0 | Small progress-entry modals did not scroll when the keyboard or large text reduced space | Scrollable goal adjustments, milestones and numeric habit entry |
| P1 | Default body, tile subtitles and item titles competed at similar emphasis | One production theme builder with deliberate size, weight, line-height and semantic subtitle styles |
| P1 | Conflict review displayed entire JSON records before the changed value | Field-first comparisons, complete-record disclosure, base-value disclosure after comparison, named selections and a selection count |
| P1 | Deletion and linked consequences needed stronger visible context | Inline text/icon notices; original resolution, bulk and partial-selection rules preserved |
| P1 | Sync/backup explanations, timestamps and connection actions competed with core actions | Shorter copy, readable local time, supporting-text roles, one primary backup action, explicit recovery notices |
| P1 | Seed-derived dialog/surface colors could ignore the user's surface choice | Palette-derived surface layers and dialog surface; original JSON/native tokens preserved |
| P1 | Completed task titles used translucent primary text despite remaining actionable | Opaque secondary semantic text, retaining strike-through and completion state |
| P2 | Sidebar uppercase, template guidance and report context had inconsistent emphasis | Sentence-case category heading, quieter descriptions and report metadata |

No database, sync protocol, conflict decision, authorization, recovery-code
lifetime, backup replacement, signing, updater or native widget behavior changed.

## Skills applied

Both installed design skills were read and used. Apple Design references:
accessibility, layout, typography, color, desktop context, buttons, modality,
settings, writing, dark mode and cross-platform translation. Specific guidance:
`layout.md > Visual hierarchy`: "Order content by relative importance" and
"Use progressive disclosure"; `typography.md > Conveying hierarchy`: "Adjust
font weight, size, and color"; `writing.md > Getting started`: "Be clear."
These informed field-first conflict review, quieter explanatory text and shared
roles. The Apple-specific appearance-switch advice does not override Todorbit's
existing customization or Windows/Android expectations.

UI UX Pro Max's Flutter search returned LayoutBuilder, TextScaler and controller
guidance. Its app checklist supplied 48 dp Android controls, semantic colors,
color-independent status, focus, safe-area and content-clearance checks. Its
broad system query returned a marketing layout and unrelated teal palette;
those were rejected. The first disclosure search was off-topic; the narrower
retry supplied relevant form-label and submit-feedback guidance. Progressive
disclosure itself is supported by the Apple layout reference, not that search.
No remote skill code or new fonts/dependencies were installed.

## Shared rules

| Role | Logical size | Treatment |
| --- | ---: | --- |
| Page | 28 / compact page 24 | Semibold, primary |
| Dialog / major heading | 22 | Semibold, primary |
| Section | 18 | Semibold, primary |
| Item / setting | 15 | Semibold items; medium list labels |
| Body | 14 Windows / 15 Android; large body 16 | Regular, primary, 1.45-1.5 line height |
| Supporting / helper | 13 | Regular, opaque secondary, 1.4 line height |
| Compact metadata | 12 | Secondary |
| Error / warning | Body + icon/title | Semantic error or readable neutral notice; text carries meaning |
| Disabled | Material state styles | Existing disabled semantics and interaction preserved |

`AppSpacing` provides 4/8/12/16/24 logical-pixel rhythm for shared sections,
notices and action bars. Existing responsive editors, padding and native widget
tokens are reused. Android keeps 48 dp minimum actions, Windows 40 px buttons
and compact density. TextScaler remains unbounded by this change; no font
clamping or new animation, blur, database access or network work was added.

Built-in surface text contrast remains 16.50/13.96 primary and 6.05/8.92 secondary
(light/dark). Custom explicit text colors remain user controlled; action
foregrounds choose the stronger black/white pairing. Automated contrast checks
cover both stock themes, scaffold/surface text and primary/error actions.

## Inventory and review coverage

The source review follows Architecture Map entry points and existing rendered
reports. It examines structure and shared styling; it is not a claim that every
line, state, menu or platform interaction was independently exercised.

| Surface family | Source reviewed / retained patterns |
| --- | --- |
| Today, Inbox, all tasks, Upcoming, category/project and saved task views | Workspace/mobile lists, headers, counts, filters, sort, task rows, category menus, detail panel, quick search and advanced search |
| Task creation/details | Title/notes, planned day/deadline separation, resources, checklist/subtasks, recurrence/progressive plan, series/sequence dialogs, unsaved guard and trash confirmation |
| Calendar/events/sessions | Desktop/mobile calendar, day preview, event/session editors, contextual creation, cancellation, recurrence and scheduling history |
| Goals/habits/routines/templates | Feature views, goal/habit editors, progress/milestones, numeric entry, template list/apply/delete; routines use existing habits/templates rather than an invented new screen |
| Actual work and focus | Timer state, review, ownership, history, fixed actions; no timing/ownership changes |
| Reports | Header, date range, metrics and metadata |
| Navigation/search | Sidebar, mobile drawer/bottom navigation, settings rail/picker, menus/tooltips and anchored select controls |
| Appearance/themes/customization | Theme editor, color picker, task display/defaults, sidebar order and hotkeys; preserve imports and presets |
| Widgets | Flutter configuration/editor and native Windows/Android typography, semantic palettes, accessible labels and size rules; no native repaint changes |
| Notifications/privacy | Permission/delivery copy, settings, PIN lock and unlock, visible warnings and existing recovery behavior |
| Backup/import/export | Local embedded backup actions/history, cloud account/actions, passphrase, restore confirmation, restart/cancel and settings transfer |
| Sync | Setup, pairing/recovery-code entry/display, automatic/pending/status, conflict comparisons, bulk choices, deletion/related records, restore reconciliation and errors |
| Updates | Windows/Android status, channel, partial-download controls, notes and install permission/unsigned warnings; underlying updater unchanged |
| Contributors/support | Registry view, official links, donation action and reduced-motion introduction; no registry/destination changes |

Rendered evidence and exact test results are recorded in the ledger below.
Physical Windows resize/DPI/Explorer input, phone/OEM/TalkBack and real Drive
pairing/exchange are not inferred from widget tests or emulator screenshots.

## Invocation ledger

Development source is baseline `aae8928` plus the task diff until committed.
Logs are under ignored `.buildlog/ui-audit/`; capture data is synthetic only.

| Invocation / purpose | Result / evidence | New or rerun reason |
| --- | --- | --- |
| Remote releases API + `git ls-remote --tags origin v1.0.19*` | Latest beta.4/code 27; beta.5/code 28 selected | New version/order check |
| Conflict visual fixture, initial | Compile failed: missing ImageByteFormat import | New capture harness |
| Same fixture after import | Passed, but default test font was unsuitable for visual review | Corrected harness |
| Same fixture with unchanged extracted baseline theme and system font | 1 pass; four before images | Rerun for readable, production-theme evidence |
| Targeted seven-file analysis | One lint: indirect intl dependency | New; replaced with existing Material localizations, no dependency added |
| Focused conflict/backup/remaining-dialog/mobile/editor suite | 33 pass, 2 stale backup style/copy assertions | New affected-boundary check; assertions updated for intended UI |
| Whole-project analysis | Duplicate import warning | New shared-theme check; duplicate removed |
| Backup + Android/Windows updater follow-up | 12 pass, 1 old Status-label assertion | Rerun backup after assertion change; new updater coverage; label assertion corrected |
| Windows computer-use initialization | Failed: missing kernel assets | New live automation attempt; no UI action performed |
| DTD discovery/connect | IDE DTD connected, no running app initially | New live diagnostic |
| Isolated Windows driver launch | Pending; `.buildlog/ui-audit/windows-live.log` | New debug build/live review, verified child APPDATA/LOCALAPPDATA under task root |
| Retained production emulator boot on 5584 | Pending; emulator logs | New disposable runtime review, no data reset |

Reused evidence: beta.4 receipt documents production signer, profile/IPC/AppId,
mocked Drive, native widget behavior and prior acceptance limits. It is context,
not proof of changed Flutter UI or the next packages. New exact-source CI,
artifact signing/alignment/hash/runtime and updater gates are required before
publication. Native painting/input code is unchanged, so its historical renders
are retained as dated context; no new physical acceptance is claimed.

## Integration checkpoint

- The production-theme suite passed 48 cases and exposed three mobile event-link
  cases with the same color-row overflow. The event swatch labels were constrained
  with Expanded/ellipsis. The affected mobile/editor/anchored-select rerun passed
  31 cases, including all three links, narrow layouts and keyboard selection.
- The baseline visual fixture was rerun with actual text and Material icon fonts:
  one pass, four captures. This supersedes the initial missing-glyph images.
- Windows driver screenshots observed populated Today and task entry in dark,
  Calendar/event entry, settings/backups/disconnected sync and goals/habits in
  light. Two hot reloads passed; runtime diagnostics reported no errors. The
  resolved SQLite path was verified beneath the isolated task APPDATA root.
  The debug app was closed; no personal profile was used.
- The first emulator was an older retained beta guest, not the prior acceptance
  guest; it lacked the package service despite a boot flag. It was stopped with
  its data retained. The provenance receipt identified ProductionFast under
  the dedicated TodorbitReleaseAcceptance AVD root; that code-27 disposable guest
  booted successfully, with its first-install timestamp still 2026-10-31.
- Formatting invocations, UTF-8 scan and diff checks cover the touched files.
  `python tools/dev/check-docs.py` passed with zero errors. No local full suite
  was repeated: exact-source Windows CI will supply the mandatory full gate.

Additional invocation identities: `production-theme-tests.log` (48 pass/3 fail),
`event-layout-followup.log` (31 pass), `baseline-final.log` (1 pass),
`docs-check.log` (pass), `analysis-clean.log` (pending),
`conflicts-final.log` (pending; new disclosure test and 200% text geometry),
`emulator-fast*.log`, `capture-live.log`, `capture-sync.log` and Windows
driver/DTD operations above. The capture script emitted Flutter's stderr
connection messages through PowerShell's native-error stream; the PNGs exist.
One driver wait used the short label New event rather than the actual New
calendar event and timed out; the subsequent screenshot showed the editor.
These diagnostic timeouts do not count as rendering failures or passes.

## Visual evidence

Offscreen Flutter renders use the actual baseline/candidate theme and conflict
widget with synthetic records. They are not native Android or physical Windows
screenshots. All complete records remain available on demand.

| Layout | Before | After |
| --- | --- | --- |
| Desktop dark | [Before](images/ui-hierarchy/before-desktop.png) | [After](images/ui-hierarchy/after-desktop.png) |
| Phone light | [Before](images/ui-hierarchy/before-phone.png) | [After](images/ui-hierarchy/after-phone.png) |

`conflicts-final.log`: five checks pass, including compact 200% light/dark,
privacy dismissal, bulk-selection safety and complete-record disclosure.
The single-conflict desktop dialog now uses a shorter preferred height; long
content remains scrollable and mobile retains the available height.

## Final source refinement

Before packaging, the remaining dense full-cloud-restore confirmation was split
into backup summary, visible replacement/recovery guidance and Restore details.
Source/target IDs/paths, app version and included settings remain accessible.
The existing settings fingerprint check, recovery export and schedule call remain
unchanged and approval/cancellation retain the same result.

`restore-review.log`: 11 pass (four new portrait/landscape, light/dark checks with
200%/150% text, plus seven existing cloud backup/restore checks). Warnings remain
in the main scroll area, actions stay visible and Details expands; cancel returns
false and never schedules replacement. `restore-analysis.log` covers only the new
boundary; the prior full analysis passed (`analysis-clean.log`, 291.6 seconds).

The first candidate `3c94188` CI runs 41358317755/41358371855 were canceled after
this final UI source change; they are not release evidence. Both exact-source
workflows must run on the final commit. No artifact was built from that first
candidate. A private draft exists without assets; its target will be updated to
the final source before upload. This is the specific reason for the CI rerun.

Final Windows debug rebuild and hot reload succeeded (8 libraries); the changed
event editor was observed in light mode. Runtime errors and final profile identity
are checked before closing this isolated app. Native source was not repainted.

## Large-text CI correction

Final source 56fd49b passed Android CI 41358780962. Windows CI 41358780221
passed analysis and 575 host checks, with two failures and one existing opt-in
skip. Both failures were the 200% conflict bulk-choice checks: the fixed title
consumed too much space with the wider default CI font. The font-enabled local
capture run had not exposed this. A no-font local reproduction also failed both.

The title now joins the scrolling content at large text or short window heights;
Apply Selected and the count remain outside that scroll. This is a presentation
fix, preserving all resolution and privacy rules. The same five tests without
capture fonts pass in `conflicts-large-title.log`; hit-testability is now asserted.
No passing assertion was weakened. The temporary geometry print was removed.

Packages produced from 56fd49b passed signing/alignment/identity, Windows CRC and
28-file bundle equality, native self-test, Sandbox install/data retention and
portable swap/rollback. They remain private historical evidence. The large-text
runtime change invalidates those package hashes and exact-source CI for release.
Fresh packages and required checks are therefore rebuilt/rerun; the prior draft
still has no assets and no public tag/release was created. The version remains
beta.5/code 28 because beta.4/code 27 is still the newest published release.

## Final keyboard visibility correction

Source 086a6d3 passed Windows CI (577 pass/one opt-in skip), Android CI (71 host
checks/two integrations), exact APK 16 KiB runtime, signing/alignment and private
draft integrity. The retained production emulator passed a 27->28 update: its
first-install timestamp, all 53 exported tables including personalization, and
home widget IDs 2/3/providers/options were preserved. Those packages stayed private.

A repeated actual Release check at 200% text confirmed that opening the Android
keyboard could leave the recovery input outside the dialog's visible scroll area.
The setup page now observes keyboard/window metrics and keeps the focused recovery
field visible after layout. The observer/focus node are disposed with the page;
no recovery-code, pairing, authorization or persistence behavior changes.

`recovery-keyboard-final-tests.log`: six focused checks pass, including keyboard
insets, 200% conflict selection, privacy dismissal and disclosure. Initial new-test
runs exposed double disposal in the provider-owned fixture; an explicit shutdown
inside fake time then stalled cleanup. The owned test process was stopped and
cleanup moved into tester.runAsync. These fixture failures do not represent
application data failures. `recovery-keyboard-analysis.log` is clean.
The actual keyboard screenshots, not the fixture failure, establish the original
UI defect. Final package hashes/CI/runtime are regenerated for the correction.


### Keyboard timing follow-up

The signed source 365de86 still hid the field after the real Android IME settled;
its passing synthetic-inset test did not establish device behavior. The next
correction debounces focus/window metrics for 250 ms, then requests a frame and
reveals the field after layout. Disposal cancels the pending timer. The test also
advances past the bounded delay. No code is entered and setup is never activated.

| Invocation / purpose | Source | Result / reason |
| --- | --- | --- |
| `flutter test --no-pub test/sync_conflicts_dialog_test.dart` (`recovery-settled-tests.log`) | 365de86 + timing correction | Six pass; rerun because metrics timing changed |
| `tools/build-android.ps1 -Mode Release -Distribution github -SplitPerAbi -GoogleDrive` (`recovery-settled-apk.log`) | same timing correction | Diagnostic signed build for actual IME verification before final packaging; pending observation |

Windows CI 41385444959 passed at 365de86. Its 16 KiB run 41386317616 failed while
pulling a missing UI dump; that runtime gate is unverified, not a pass. Source
changes invalidate its exact-source release gates regardless. New final APK
runtime evidence must pass before publication.


The standalone diagnostic APK command initially failed before packaging because
its environment omitted Visual Studio CMake/Ninja (CXX1300). The corrected
invocation uses the established release script PATH; log
`recovery-settled-apk-env.log`. This is an environment correction, not a source
change or data reset. Focused `dart analyze` writes
`recovery-settled-analysis.log`; its completion is recorded at the final gate.


The corrected signed diagnostic APK passed two real IME focus checks on retained
ProductionFast at 200% text: the focused field remained fully above the keyboard
(bounds [78,470]-[642,668]). No recovery text was entered or setup activated;
system text scale was restored. Private screenshots/XML and the observation JSON
retain the evidence; no saved account label is published. Focused analysis is
clean. The final committed build will receive the same identity/runtime gates.
