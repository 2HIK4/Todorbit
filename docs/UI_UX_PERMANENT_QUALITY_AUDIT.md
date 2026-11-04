# Permanent UI quality: audit and implementation — 2026-11-04

**Application-wide work remains in progress.** The first completed pass is now
committed as `c32329c`. The continuation below advances the existing 40-group
inventory; discovery-only rows are not completed quality reviews.

Initial baseline `25874c0`, branch `feature/permanent-ui-quality`. Audit + implementation;
the continuation authorizes local commits, with no push/publication. Storage changes in
`DEVELOPMENT.md`, `STORAGE_CLEANUP_2026_11_04.md` and `STORAGE_MAINTENANCE.md`
are unrelated and preserved. No version/schema/protocol/key changes authorized
by this UI pass. Evidence: ignored `.buildlog/verify/permanent-ui-quality/`.

## Loaded guidance and evidence boundaries

Read root AGENTS, Codex workflow/UI quality workflow, Architecture map, relevant
Architecture/Testing/Android/Development/native widget sections, Design and
Theming. Applied the canonical Ultimate UI/UX entry point, audit/matrix/report,
complete original 28-group symptom catalog, relevant fix patterns and Flutter
engineering/verification; Todorbit regression and system skill-creator. No nested
AGENTS was found by the repository file inventory. The complete named Problem
Encyclopedia was not located in `.agents`/`docs`; the request's 67-category
inventory is the explicit baseline, not a claimed reproduction of that reference.

Reviewed prior Stage 2 audit, Sync verification, optional encryption and beta11
receipts plus the persistent ledger. Historical runtime results are not current
visual acceptance. Relevant source/assertion/dependency/environment comparison
precedes checks; unchanged native/domain/package tests are not repeated for
presentation-only changes. Source, automated, offscreen render, live visual,
interactive and physical-platform evidence are recorded separately below.

## Invocation receipt

Each execution will be recorded here with exact command/procedure, local time
(Asia/Amman, UTC+03:00), source fingerprint, reason and actual result. Machine
logs/manifests remain in the evidence directory. Planning is not a passed check.

| ID / time | Command/procedure and scope | Source / reason | Result / evidence |
| --- | --- | --- | --- |
| D01 | Dart MCP `dtd(command: list)` | Initial capability discovery | Failed argument validation; allowed command names returned. No app action occurred. Corrected to `listDtdUris`, then `connect` to discovered IDE daemon: connected, no apps. |

## Permanent routing and skill upgrade

Root [AGENTS](../AGENTS.md#skills-and-documentation-routing) is the mandatory
instruction mechanism. It now names direct and indirect UI impact, Windows and
Android Flutter/native surfaces, refactors, reviews/tests, optimization and
backend/async state changes. Unrelated service work is explicitly exempt.
The [workflow](CODEX_WORKFLOW.md#ui-quality-workflow) owns execution details;
the canonical skill owns design/inspection guidance. No competing skill or
global configuration was added. A focused task reads the entry point and relevant
reference rows once; comprehensive audits assess every category's applicability.

New references:

- [Design standards](../.agents/skills/ultimate-ui-ux/references/design-standards.md):
  all ten UX Necessity questions, semantic typography/hierarchy, shared tokens,
  Windows/Android conventions and proportionate accessibility criteria.
- [67-category inventory](../.agents/skills/ultimate-ui-ux/references/problem-coverage.md):
  numbered detection/evaluation, conditional correction and verification for
  every supplied category. Six domain groups provide lightweight routing.
- [Local-first journeys](../.agents/skills/ultimate-ui-ux/references/local-first-journeys.md):
  setup, local/offline use, manual/automatic checks, reconnect/account changes,
  conflict attention/resolution, replacement/recovery and background/lock.

Existing audit, matrix, report and source references now cover all four defect
classes, seven coverage dimensions, separate implementation/experience
inspections and evidence levels. The useful original 28-group symptom playbook
is retained as optional deeper diagnosis; its numbering is explicitly local.
Additional probes cover Flutter identity/IME/PageStorage/disposal/nonlinear text,
Windows HWND/DPI/IPC ownership, Android RemoteViews/capabilities/OEM jobs, and
local-first generations, durable resolutions, attachment integrity and timer
ownership. They are hypotheses, not invented product defects.

Current primary Windows, Android, Flutter and WCAG sources were consulted and
linked in the skill's [Sources](../.agents/skills/ultimate-ui-ux/references/sources.md).
This establishes evaluation targets, not accessibility certification.

## Routing scenarios: documentation review

| Hypothetical task | Rule exercised | Outcome |
| --- | --- | --- |
| Add a new setting | New controls and settings journey | Mandatory skill; relevant settings/state rows |
| Fix the Save button | Controls, saving, errors and feedback | Mandatory skill; behavior and experience checks |
| Improve the Sync popup | Popup, cloud status and recovery journey | Mandatory skill; overlay and local-first references |
| Refactor the task editor | UI refactoring even if appearance is preserved | Mandatory skill; draft/focus/layout regression scope |
| Fix Android keyboard overlap | Input, insets, responsive Android interface | Mandatory skill; IME/Back and geometry guidance |
| Change widget colors | Native or Flutter widgets, themes and paint | Mandatory skill; native token/evidence gates as applicable |
| Improve Calendar screen performance | Optimization with user-facing effects | Mandatory skill; measured frames plus retained behavior |
| Add a feature with a new screen | New interface and navigation | Mandatory skill; Build and necessity review |
| Fix displayed values after backend state update | Indirect service/state impact | Mandatory skill; trace state through projection and feedback |
| Change service with no UI/UX impact | Explicit unrelated-backend boundary | No UI skill/full audit required; relevant engineering checks only |

All ten scenarios route as intended in this manual instruction review. Canonical
path and local references/anchors are checked separately below. Scoped hidden-file
inventory found only the root AGENTS and one project Ultimate UI/UX skill; the
regression skill supplements it. This is documentation-routing evidence, not a
guarantee that every future agent/session will comply or discover updated metadata.

## Findings and implemented corrections

Critical = P0, High = P1, Medium = P2, Low = P3. No Critical/High application
defect was confirmed in this pass. Source findings are not claimed as reproduced
on physical Android. Five confirmed UI findings form one cohesive Sync pass.

| ID / severity / class | Platform and observed problem | Expected experience / root cause | Correction and evidence |
| --- | --- | --- | --- |
| U01 Medium, usability/trust | Android Settings > Sync says “Encrypted incremental changes” for Standard Sync too | Do not imply device-side encryption for readable Standard data. Confirmed hardcoded subtitle despite approved two-mode implementation | Mode-neutral “Sync across devices with Google Drive”; source and compact settings interaction T03. Physical Android NOT TESTED |
| U02 Medium, usability/visual | Shared Sync settings presents replacement warnings/action before Automatic sync; ordinary users encounter destructive recovery before routine control | Routine use should lead; replacement remains discoverable with explicit safeguards. Confirmed child order | Automatic sync precedes encryption; replacement moves into labeled Recovery. Pending replacement reopens it after manual collapse. T02/T04/T05 cover desktop/light and compact/dark/Dusk, review/cancel, unchanged disabled-until-acknowledged confirmation |
| U03 Low, visual | Account detail and repeated unlock explanation use primary body treatment beside headings | Supplemental content should remain readable but quieter. Confirmed local Text styling bypasses helper role | Reused SettingsHelperText; live disconnected Windows light/dark and offscreen recovery renders inspected; no global token changes |
| U04 Low, content | Two recovery explanations contain literal `device?s` | Readable recovery consequences. Confirmed source string corruption | Reworded without encoding-sensitive apostrophes; source diff and expanded recovery PNGs |
| U05 Medium, usability/content | Recovery-code-only state is labeled “Password required,” including credentials problem mapping | Identify the required unlock without implying an unavailable password method. Confirmed controller/problem label literals | “Unlock sync to continue” in both mappings; T06 checks actual recovery field and credentials error route in both themes. Recovery/crypto semantics unchanged |

Process findings: mandatory rule omitted explicit indirect state/service and
optimization cases; root Sync prohibition contradicted the approved implementation;
the skill had no complete 67-category inventory or mandatory necessity/two-pass
review. These are corrected above. The Sync guide also distinguishes current local
UI from recorded beta11 publication; historical beta9 evidence remains historical.

Both inspections were applied: implementation retained callbacks/guards, encrypted
credential requirements and confirmation; experience review removed competing
recovery emphasis, misleading terminology and unnecessary primary-text emphasis.
The routine journey adds no clicks. Recovery adds one deliberate disclosure in
ordinary state; pending review opens automatically. All advanced/recovery actions
remain available. No automatic data decision, pairing shortcut or safety warning
was removed. No deeper Sync architecture change was made.

## Actual surface inventory and coverage

Reconciled current sidebar/workspace entries, desktop settings enum (ten sections),
mobile settings routes, feature declarations/labels, nested dialog calls, architecture
map and native adapters. The prior Stage 2 list was a discovery aid, not acceptance.

**D** = discovered entry/owner only; **S** = relevant source inspected; **A** =
automated widget evidence this task; **V** = live Windows visual inspection;
**I** = Driver interaction. D/S do not establish visual quality. A/V/I apply only
to the named sample; every unlisted state/platform combination is NOT_TESTED.
Unexecuted native/device checks are NOT_TESTED; a known access/tool blocker is
recorded as BLOCKED, never passed.

| ID | Actual surfaces / owner under `lib/features/` unless noted | Platform | Evidence this task and limits |
| --- | --- | --- | --- |
| S01 | Today, All tasks, Inbox, Anytime, Upcoming, Overdue, Waiting, Completed; workspace/mobile shells | W/A | S; V/I Today empty and one synthetic task, light after restart. Other filters/mobile runtime NOT_TESTED |
| S02 | Task create/details/editor, planned day/deadline, organization, status/priority, estimates/protection | W/A | S; V/I Windows new title → Create task → persisted task. Advanced fields/Android IME NOT_TESTED |
| S03 | Checklist, subtasks, dependencies, draft/saved composition | W/A | S declarations/labels; populated/reorder/unsaved runtime NOT_TESTED |
| S04 | Links/files/folders/managed attachments, relink and open/remove confirmations | W/A | S actions/labels; native pickers/permission/failure NOT_TESTED |
| S05 | Series scopes/recurrence/progressive plans/sequences | W/A | S entry/form labels; occurrence/future/end/skip runtime NOT_TESTED |
| S06 | Event editor/details, all-day/repeat, colors/icons/custom detail types, cancel/end/trash | W/A | S entry/form inventory; actual event editing NOT_TESTED |
| S07 | Planned session create/edit/delete/outcome | W/A | S declarations/labels; runtime NOT_TESTED |
| S08 | Desktop Calendar day/week/month, day preview/context actions | W | S; V/I week displays same synthetic task/date. Other modes/dense events NOT_TESTED |
| S09 | Mobile calendar day/week/month and agenda/date selection | A | D; runtime NOT_TESTED |
| S10 | Categories/projects management, rename/delete, category icon/event color | W/A | S workspace/mobile menu labels; full journey NOT_TESTED |
| S11 | Quick/advanced search, filters/sort, saved views | W/A | D; zero/many results and saved-view journey NOT_TESTED |
| S12 | Template/routine save/apply/delete | W/A | S entry/forms/labels; application/persistence NOT_TESTED |
| S13 | Smart Reschedule preview/approval, availability, schedule history/restore preview | W/A | S entry/forms/labels; approve/error/recovery runtime NOT_TESTED |
| S14 | Habits editor/log/history/rest/archive | W/A | S declarations/labels; populated/empty runtime NOT_TESTED |
| S15 | Goals editor/links/milestones/progress/history/archive | W/A | S declarations/labels; runtime NOT_TESTED |
| S16 | Timer/focus/start/pause/stop/take control, manual work editor/delete | W/A | S entry/forms and checkpoint warning; runtime NOT_TESTED |
| S17 | Statistics/report periods/custom date/values | W/A | S declarations/periods; runtime/data correctness NOT_TESTED |
| S18 | Archive/Trash, restore/permanent deletion | W/A | S entry/confirmation labels; runtime NOT_TESTED |
| S19 | Desktop Settings hub/compact picker, mobile settings/navigation | W/A | S; V/I desktop section navigation, A compact mobile settings T03. Complete nested navigation NOT_TESTED |
| S20 | System/light/dark mode, custom palette/presets/import/export/color picker | W/A | S tokens/theme infrastructure; V/I light/dark switch, light retained on restart. Arbitrary imported palette/save/cancel NOT_TESTED |
| S21 | Task defaults/display, sidebar order, opening page, week start/calendar content | W/A | S desktop/mobile routing; persistence/runtime NOT_TESTED |
| S22 | Hotkeys/search/rebind/presets/conflicts | W | D; actual rebinding/keyboard NOT_TESTED |
| S23 | Notifications/daily summary/due reminders/quiet hours/permission links | W/A | S labels, A mobile settings entry; OS delivery/permission NOT_TESTED |
| S24 | PIN/app lock/idle/focus/biometric/privacy controls and locked entry | W/A | S form/route inventory, A existing Sync privacy-closure cases T01. Actual PIN/Hello/TalkBack/lock capture NOT_TESTED |
| S25 | Data profile/import/export, startup migration/recovery/legacy prompts | W/A | S storage/route boundaries; isolated runtime profile/integrity observed. Migration/import runtime NOT_TESTED |
| S26 | Local snapshots/actions/history/retention, restore confirmation/restart | W/A | S labels; V/I Windows backup parent only. Create/import/restore NOT_TESTED |
| S27 | Drive account/snapshots/upload/download/delete/passphrase/history | W/A | S current guide/entry and disconnected copy; V disabled Windows parent. Live OAuth/cloud BLOCKED by no isolated account/configuration |
| S28 | Sync status badge/settings/manual/automatic/progress/errors | W/A | S; A disconnected/ready/recovery/synced/offline/conflicts, long account, 200% light/dark T01/T06; V/I disconnected Windows light/dark. Actual exchange BLOCKED |
| S29 | Private setup, passphrase/recovery acknowledgment, reveal/hide/unlock | W/A | S route/guard; A setup validation/large text/privacy/spaces T01, code-only status T06. Real protected credential storage/another device NOT_TESTED |
| S30 | Start New Sync review/snapshot/acknowledgment/reconnect/resume/cleanup | W/A | S; A confirmation/guards and Recovery reveal T01/T02/T05. Service/real cloud destruction was not executed |
| S31 | Conflict compare/complete records/bulk choices/apply/confirmation/defer | W/A | S; A T01 compact/large-text/short-landscape/lock/control counts and no implicit apply. Live two-device propagation NOT_TESTED |
| S32 | Settings transfer category selection/path/merge/apply confirmation | W/A | S labels/confirmation inventory; runtime NOT_TESTED |
| S33 | Windows updates/channel/check/download/pause/retry/install/release notes | W | D; network/install runtime NOT_TESTED |
| S34 | Android GitHub/Play updater/download/permission/install | A | D; device runtime NOT_TESTED, no build/install performed |
| S35 | Widget enable/configure Tasks/Calendar, preview/apply/all/cancel/presets/history | W | D/source boundary; preview/persistence NOT_TESTED |
| S36 | Native Tasks widget, quick add/editor/context menu/tray/date popup | W native | D architecture/checklist; shell/input/DPI/reader NOT_TESTED; unchanged native boundary |
| S37 | Native Calendar grid/agenda/divider/navigation/menu | W native | D architecture/checklist; painting/interaction NOT_TESTED; unchanged native boundary |
| S38 | Android Tasks/Calendar launcher widgets/configuration/entry/one-use completion | A native | D architecture/adapter; real launcher/OEM/Back/TalkBack NOT_TESTED; no device session used |
| S39 | Support introduction/payment link/feedback and Contributors | W/A | D routes; runtime NOT_TESTED |
| S40 | Shared selectors/date/color/icon pickers, tooltips, prompts, unsaved guard, spelling review | W/A | S reused helpers/theme and Sync modal use; A Sync Escape/scroll/confirmation. General picker/spelling states NOT_TESTED |

No independent standalone onboarding screen was found in navigation; fresh Today
and contextual introductions are actual first-use surfaces. No speculative missing
feature was implemented. iOS and the separate website/web runtime are outside this
app audit. Inventory coverage is broad; depth is intentionally uneven and explicit.

## Seven-dimensional sample and category applicability

- Surface: 40 discovered groups above; only named samples executed.
- State: disconnected, ready/unpaired, recovery, up-to-date, offline, conflicts,
  pending replacement/review, collapsed/expanded, invalid/confirmed/cancelled,
  locked closure and empty/populated synthetic data. OS permission/real network
  failures not simulated in the live app.
- Environment: Windows Debug 1264x681 logical screenshot; host fixtures 1280x800,
  1100x800, 390x844, 360x640 at 200%, 640x360 at 200%, reset 380x780 at 200%;
  light/dark and nondefault Dusk palette. Dusk fixture is named “custom”; this
  does not prove arbitrary imported customization or physical nonlinear scaling.
- Interaction: Driver taps/text, widget scroll, selection, confirmation, Cancel,
  Escape and focus/IME visibility cases. Physical keyboard/mouse, DPI and Android
  touch/Back/gesture behavior remain unobserved.
- Journey: empty first use, create task, settings/theme navigation, Sync recovery
  disclosures, failure action, interruption via hot restart. Long-running actual
  background/account recovery journeys remain unverified.
- Data: in-memory/disposable synthetic records, long account/notes, zero/one task;
  large datasets/outdated/concurrent real devices not exercised here.
- Quality: hierarchy, truthful wording, reduced decision burden, action geometry,
  state/callback correctness and retained draft/recovery protections. No measured
  performance benchmark or real reader/compliance claim.

All 67 reference rows assessed for applicability: 1–10 map to navigation/settings
and Sync journeys; 11–20 to theme/shared controls; 21–35 to forms/collections/
calendar; 36–38 and 40–46 to W/A inputs/accessibility/native surfaces; 47–59 to
state/Sync/offline/backup/privacy/updates; 60–67 to profile-scoped companion/worker,
dates/recovery/automation/ethical support and engineering evidence. **39 is N/A**
for the native app (separate website excluded). Applicability does not mean all
checks were executed; table gaps remain authoritative. Supported English content
and mixed-direction data were considered; translation completeness is unverified.

## Exact automated invocation history

All times below are 2026-11-04 **UTC+03:00**. Baseline `25874c0` plus dirty UI
source; machine JSON receipts record per-file SHA-256 and patch hashes. Source
receipts/logs are under `.buildlog/verify/permanent-ui-quality/`. `run-check.py`
is an ignored log wrapper; the exact underlying commands are listed here.

| ID / time | Exact command and purpose | Result / reason and receipt |
| --- | --- | --- |
| F01 04:45:08 | `dart format lib/features/settings/sync_settings_page.dart lib/features/mobile/mobile_settings.dart test/sync_conflicts_dialog_test.dart` | PASS, 3 formatted; new edits. `format-044508.json` records pre-format hashes |
| A01 04:45:22 | `dart analyze lib/features/settings/sync_settings_page.dart lib/features/mobile/mobile_settings.dart test/sync_conflicts_dialog_test.dart` | Exit 0, two existing page curly-brace infos; no errors. Two braces corrected. `analyze-044522.json` |
| M01 04:45:22 | `python C:/Users/User/.codex/skills/.system/skill-creator/scripts/quick_validate.py .agents/skills/ultimate-ui-ux` | BLOCKED: installed Python lacks `yaml`/PyYAML. `skill-044522.json`. Existing Node `import('yaml')` also unavailable; no dependency installed |
| T01 04:46:16 | `flutter --no-version-check --suppress-analytics test --no-pub --concurrency=1 --reporter=expanded --timeout=2m test/sync_conflicts_dialog_test.dart` | 27 PASS, 3 new cases FAIL: fake-clock wait on real reset-cancel file I/O, followed by teardown lock errors. Fixture now overrides cancellation with observable count/state. `sync-ui-044616.json/log`. Wrapper's final console tail also hit cp1252 encoding; receipt/log survived; wrapper output encoding corrected |
| T02 04:47:45 | `flutter --no-version-check --suppress-analytics test --no-pub --concurrency=1 --reporter=expanded --timeout=2m test/sync_conflicts_dialog_test.dart --plain-name "routine Sync precedes recovery"` | PASS 3; rerun only failed cases after cancellation fixture fix. `recovery-fix-044746.json` |
| T03 04:48:30 | `flutter --no-version-check --suppress-analytics test --no-pub --concurrency=1 --reporter=expanded --timeout=2m test/mobile_workspace_test.dart --plain-name "mobile settings expose daily reminders and independent navigation"` | PASS 1; changed subtitle/compact settings interaction. `mobile-settings-044831.json` |
| F02 04:50:37 | `dart format lib/features/settings/sync_settings_page.dart lib/features/mobile/mobile_settings.dart test/sync_conflicts_dialog_test.dart` | PASS; only test capture additions changed formatting. `format-045038.json` |
| T04 04:50:49 | Same exact T02 command | PASS 3; added opt-in recovery captures to inspect previously unobserved expanded layout. `recovery-fix-045049.json`. Initial compact captures were from the pre-scroll painted frame; not accepted as visual proof |
| A02 04:50:49 | Same exact A01 command | PASS, no issues after page brace/test-capture edits. `analyze-045049.json` |
| T05 04:52:13 | Same exact T02 command | PASS 3; added post-scroll pump and full label-above-footer assertion to reconcile T04 image/geometry discrepancy. `recovery-fix-045216.json`. Final light/dark/Dusk PNGs inspected; warnings/action/Close reachable |
| F03 04:53:18 | `dart format lib/features/settings/sync_settings_page.dart lib/features/mobile/mobile_settings.dart lib/app/sync_controller.dart lib/data/cloud/sync_problem.dart test/sync_conflicts_dialog_test.dart` | PASS, 5 files, zero formatting changes. `format-045319.json` |
| T06 04:53:32 | `flutter --no-version-check --suppress-analytics test --no-pub --concurrency=1 --reporter=expanded --timeout=2m test/sync_conflicts_dialog_test.dart --name "Sync recovery at 200 percent text\|specific sync errors"` | PASS 3; new unlock wording/assertions invalidated only these prior cases. `unlock-label-045332.json`. The backslash in this Markdown table only escapes the separator; actual argument is the regex alternation shown in JSON |
| A03 04:53:32 | `dart analyze lib/features/settings/sync_settings_page.dart lib/features/mobile/mobile_settings.dart lib/app/sync_controller.dart lib/data/cloud/sync_problem.dart test/sync_conflicts_dialog_test.dart` | Exit 0, no errors/warnings, **two pre-existing controller curly-brace infos** at lines 42/449. They are outside the display-label edit and retained. `analyze-045332.json` |

31 distinct widget cases covered across the scoped runs (30 Sync + one mobile),
not an assertion that a fresh full current suite was run at once. T01's unaffected
24 passes remain valid; two recovery and one error-action cases are replaced by
T06, and the three new recovery cases by T05. Later changes are display-label
literals only; the routine layout, cancellation fixture and remaining assertions
are unchanged. Font/capture additions affect only those three new tests. No
golden baseline was created or replaced.

Reused backend evidence: [beta11 safety/adapter receipt](SYNC_START_NEW.md),
[optional encryption](SYNC_OPTIONAL_ENCRYPTION.md) and
[comprehensive Sync verification](SMART_SYNC_VERIFICATION.md) remain evidence for
their recorded behaviors. Comparison against `c8f1561` found no domain, schema,
transport, Android/native, dependency or package changes before this pass; final
controller/problem diffs contain only unlock-label literals. This does not extend
old live-device acceptance or imply live Drive ever passed. Full suites/native
Release/self-test/APK/installer/CI were **NOT RUN**, because those boundaries did
not change and this is not release work. Mandatory future release gates remain.

## Live Windows and manual evidence

Procedure R01 (04:42–04:54):

1. `python .buildlog/verify/permanent-ui-quality/launch-runtime.py` launches
   `flutter --no-version-check --suppress-analytics run --no-pub -d windows --target lib/driver_main.dart --machine`.
   First Debug build/start PASS. No Release package produced. Child-only APPDATA
   and LOCALAPPDATA are under this task's `runtime-profile/Roaming` and `/Local`.
   `runtime-launch.json` records command, source/hash and process identity.
2. Before Driver input, confirmed Debug executable PID 4036, the expected SQLite
   path, schema 26, quick_check `ok`, zero tasks. First read-only Python probe
   failed converting a relative path to a URI; corrected `.resolve()` and checked
   the same profile (`profile-check.json`), without opening any personal profile.
   VM `getVM` also reports that exact Drift path; `evaluate` in `dart:io` confirms
   **both actual child environment values** match the isolated paths (true).
3. DTD `listDtdUris/connect/listConnectedApps`; connect to app daemon from machine
   log. `hot_reload` PASS after edits, again after later page edits and after final
   label changes (three successful reloads total). `get_runtime_errors`: clear on
   both executed inspections.
4. Driver `tap ByText Settings`; inspect Appearance. `tap ByText Sync`; inspect
   disconnected state; `tap ByText Encryption options`; `waitFor ByText Set up
   Private Encrypted Sync`; inspect settled expanded copy. A capture during the
   expansion animation was discarded. `tap Appearance & Themes`, `tap Light`,
   `tap Sync`; inspect light state. Connect is explicitly unavailable in this
   debug build; no account, credential, network exchange or replacement executed.
5. `tap ByTooltipMessage Close Settings`; `tap New task`; focus
   `ByValueKey task-title-field`; `enter_text UI audit synthetic task`; inspect;
   `tap Create task`; observe saved title. `tap Calendar`; inspect Week with same
   task/date. `hot_restart` PASS; Today shows same task and retained light theme.
   Read-only SQLite/appearance probe confirms one named synthetic task, schema26,
   quick_check `ok`, theme `light` (`profile-after-restart.json`).
6. Reopen Settings > Backups & Cloud; inspect disconnected/local snapshot parent
   without operating backup/restore. Existing personal installed PID21876 was
   identified and never selected or stopped. No native widget was started.

Two Driver target attempts timed out, not product failures: incorrect tooltip
case `Close settings` (corrected to source's `Close Settings`) and `Close details`
after successful task creation had already closed the editor. No save/retry was
repeated. Screenshot persistence initially exceeded Node's 64,000-byte review
limit; bounded base64 chunks safely saved images afterward. No approval or
security setting was changed.

Durable ignored screenshots: `runtime-sync-dark.png`,
`runtime-sync-options-dark.png`, `runtime-sync-light.png`, `runtime-task-light.png`,
`runtime-calendar-light.png`, `runtime-restart-light.png`; widget evidence
`renders/recovery-light.png`, `recovery-dark.png`, `recovery-custom.png` plus
existing conflict/Sync/reset capture hooks. Expanded recovery text/actions clear
the footer in final compact renders. Offscreen Material icon glyphs appear as
squares because that test font is absent; real Windows icons rendered correctly.
No pre-change live baseline was captured; before/after claim is limited to source
order/styles/strings and observed final renders. Physical input/DPI and reader
behavior are not established by Driver/offscreen images.

## Remaining work, safety and delivery

No confirmed application finding from U01–U05 remains unfixed in the checked
scope. Important coverage gaps remain: actual paired Windows/Android UI and
cross-device OAuth/exchange/reconnect/offline conflict propagation; native
background/lock timing; physical Android IME/Back/rotation/TalkBack; Windows
keyboard/Narrator/high-contrast/DPI/native menus; populated advanced forms,
widgets and update/restore flows. These are **unverified risks**, not assertions
of product defects. Verify in that order using disposable accounts/profiles;
never use personal data to turn gaps into passes.

Implementation files: shared Sync settings, mobile settings subtitle, controller
and problem display labels, existing Sync widget tests; no new production shared
component or dependency. SettingsHelperText and built-in ExpansionTile reuse the
current palette/typography; stored appearance and native token contracts unchanged.
The test fixture now exposes reset capability and stubs only cancellation, with
an observed cancel count. No schema/migration, conflict/encryption/key/ownership,
automatic scheduling, repository-write or backup-protection behavior changed.

Guidance files: root AGENTS, canonical skill plus its five updated and three new
references, Codex workflow, Sync guide, this audit, Progress and test-ledger link.
Unrelated three storage documents remain outside this task. Branch is
`feature/permanent-ui-quality`; HEAD remains `25874c0`. Changes are left uncommitted
for review, with no push, release, version bump, tag movement or publication.

The permanent routing/skill upgrade and a coherent Sync implementation pass are
complete. This report is a comprehensive discovery/coverage audit with bounded
inspection, not a claim that all 40 surface groups are polished or fully verified.

## Final guidance/diff checks

At 04:57:18+03:00, `python .buildlog/verify/permanent-ui-quality/validate-guidance.py`
PASS: actual two-scalar frontmatter syntax/name/description, 67 unique complete
numbered rows and local links/anchors across 19 Markdown files; exact input hashes
in `guidance-validation.json`. This is a scoped fallback, not a claimed successful
run of the unavailable PyYAML-based bundled validator.

At 04:57:20+03:00, `python tools/dev/check-docs.py AGENTS.md docs/CODEX_WORKFLOW.md docs/GOOGLE_DRIVE_SYNC.md docs/UI_UX_PERMANENT_QUALITY_AUDIT.md docs/PROGRESS.md docs/TEST_RUN_LEDGER.md .agents/skills/ultimate-ui-ux/SKILL.md .agents/skills/ultimate-ui-ux/references/design-standards.md .agents/skills/ultimate-ui-ux/references/problem-coverage.md .agents/skills/ultimate-ui-ux/references/local-first-journeys.md .agents/skills/ultimate-ui-ux/references/audit-workflow.md .agents/skills/ultimate-ui-ux/references/issue-catalog.md .agents/skills/ultimate-ui-ux/references/report-template.md .agents/skills/ultimate-ui-ux/references/test-matrix.md .agents/skills/ultimate-ui-ux/references/sources.md`
PASS, zero errors; `docs-links-045720.json/log`. New validation for changed links,
map and existing feature catalog; no app tests rerun for documentation. Final
receipt text and moving the Progress checkpoint to the top do not alter those
validated targets or skill metadata/category rows; that evidence is reused.

Earlier `git diff --check` PASS; final full affected diff/new-file review and
`git diff --check` are recorded in `final-review.json`. CRLF conversion notices
are Git working-copy notices, not whitespace errors. No unrelated storage file
was edited by this task.

After review, VM `getVM` identified the task's Debug PID4036 and
`ext.flutter.exit` closed its service connection before an RPC reply. OS process
inspection confirms task Debug/Flutter processes stopped; personal installed
PID21876 remains running. This was an owned-process shutdown, not a crash or
interaction with the personal app. Synthetic profile/evidence files are retained.

## Continuation: high-use workflows and remaining surfaces

User authorized continuation and local commits, without push/publication. Initial
20 files and all three unrelated storage documents match the earlier final-review
hashes. Reused existing test/metadata/reference evidence; inspected staged paths,
source diff and `git diff --cached --check`; committed only those 20 files as
`c32329c`. Missing PyYAML is still an explicit bundled-validator limitation, not
an app verification failure. No code/test rerun was justified by the commit alone.

Batch 2 starts at `c32329c`: Today/task drafts/navigation, desktop/mobile Calendar,
settings and widget controls, then other reachable surfaces. Desktop TaskEditor
callers defaulted unsaved protection off; new baseline tests reproduced loss on
close/switch/navigation before correction. Previous mobile Back receipts did not
cover those desktop paths. Actual outcomes follow; plans are never passes.
Evidence is under `.buildlog/verify/permanent-ui-quality/pass2/`.

### Completed implementation checkpoint: main workflows and enlarged layouts

Read the current working tree/diffs and applicable guidance before editing. The
permanent routing, 67 category references and earlier Sync changes are committed
and their unchanged evidence remains valid. This continuation changes presentation
and draft navigation only. No repository/schema, scheduling calculation, timer
ownership, backup, Sync, credential, native widget or stored preference format
changed. Existing callbacks and explicit Apply/Save boundaries remain.

| Finding | Reproduction / cause | Implemented correction / verification |
| --- | --- | --- |
| U06 P1, work preservation | Desktop task editor defaults protection off; close, sidebar/hotkey/task/search navigation can dispose edited fields. Saved-view creation and template application also navigate | Enable existing discard protection in desktop callers; a small editor controller coordinates confirmation before replacing an inline draft. Guard actual search/view/template navigation, category/project deletion; inspecting/cancelling dialogs adds no prompt. Thirteen draft integration cases collectively cover close, navigation, switching, accepted discard, Escape, search, saved view, template and category deletion plus Calendar editor dismissal. Live Windows Keep editing retains the draft, which then saves |
| U07 P1, responsive state | Resizing an inline draft through the 1050px breakpoint removes the editor | Keep the same keyed editor mounted in the available content pane until it closes. 1280→900→1280 widget test verifies state identity, title and actual save. Physical window resizing remains NOT TESTED |
| U08 P2, interrupted editing | Desktop Calendar and nested task/session editor callers leave unsaved guards off | Enable existing guards; Event/Work session dismissal tests pass. Existing mobile Back/save and composition save tests pass. No second draft implementation |
| U09 P2, accessibility | Desktop completion checkbox has no task name; mobile completed checkbox still says Complete | Contextual Complete/Reopen labels. Desktop semantics plus persisted completion and existing mobile completion tests pass. Actual screen-reader output NOT TESTED |
| U10 P2, Calendar identification | 200% Week label needs 68.65px but is fixed to 48px; period label needs 257.04px but is fixed to 240px | Intrinsic mode-label width with existing minimums; scale the period's reserved width with text size so mode controls stay stationary. Mode switching, whole-word/full-period geometry and stable ordinary-size controls pass |
| U11 P2, scheduling operability | At 390×700/200%, fixed header/control area consumes the dialog, causing 410px overflow | One scrollable compact flow with fixed shared action bar; preserve two-pane wide view and preview/approval logic. Review caught an introduced wide-layout regression: acknowledgment scrolled out of view; restored beside the footer. Wide/compact warning-gated Apply, non-mutating preview, Cancel, actual Apply and recurring-collision approval pass |
| U12 P2, availability layout | Enabled-day/time Row overflows horizontally by 103px at the same bounds | Wrap weekday/start/end controls, add contextual weekday checkbox names. Enable Monday → Save persists exactly 09:00–17:00 |
| U13 P2, settings failure | Task Preferences AlertDialog intrinsic sizing reaches AnchoredSelectField's LayoutBuilder and throws | Bounded Dialog with scrolling settings and shared action bar. Compact 200% toggle/undo/Done and existing light/dark narrow setting changes pass |
| U14 P2, report readability | 180px metrics break Completed inside a word while unused row space remains; selected period truncates to Last 3… | Metrics use available width and scale; selector grows; compact daily rows reflow date/value above the bar. Whole words, full range/date, switching period and persisted completion report tests pass. Calculations unchanged |
| U15 P2, time readability | Focus clock wraps its final digit onto a new line at 200% | Choose a fitting existing typography role using actual scaled text measurement; keep tabular figures and system scaling. Exceptional longer values can scroll horizontally. Enlarged clock/start/pause and ordinary start/pause/manual-log tests pass; live Windows start/pause/stop observed |
| U16 P2, destination names | Sidebar reorder controls squeeze Today/All tasks/Inbox into fragments at 200% | Put arrow actions below the named row when compact; retain drag and keyboard-operable arrows. Whole-word geometry and actual reorder pass; existing immediate navigation update test passes |
| U17 P3, heading/name | Schedule history heading splits Schedule at 200%; close icon lacks a tooltip | Reuse titleLarge; name Close schedule history. Whole-word geometry and actual close pass |
| U18 P2, date readability | Event/session date buttons split 2026-11-04 across lines at 200% | Shared DateTimeButtonRow uses AppSpacing and stacks date/time when needed. Both start/end values remain whole; corrected scrolled renders inspected. Existing event picker/title/category and narrow new/edit session actions pass. Picker callbacks, inclusive all-day display and interval logic unchanged |

Implementation inspection checked ownership, save/cancel/error paths and shared
consumers; experience inspection checked hierarchy and decision cost. The new
confirmation appears only when leaving edited work. No routine step, setting,
data field or recovery capability was removed. Report controls, timer controls,
reorder arrows, date/time buttons and scheduling approval retain their meanings;
the changes allocate room rather than shrink all text or hide required controls.
Empty, disconnected and unavailable states use real controller/service state.

### Coverage update across the existing 40 groups

This table supplements the **historical first-pass inventory**, rather than
turning its discovery rows into passes. S = implementation/experience source
inspection; O = inspected offscreen render; A = automated interaction/geometry/
semantics; V = actual isolated Windows Debug/Driver. None means physical input,
Android device acceptance or accessibility certification. Each row records visual
and hierarchy considerations, necessity/journey review, behavior/state evidence,
responsive/input/accessibility scope and remaining important states. A bounded
review is complete only for its stated sample, not every variant of that group.

| Group | Inspection and necessity decision / evidence added | Outstanding acceptance or next sample |
| --- | --- | --- |
| S01 shell/Today/lists | S/O/A empty short 900×550 at 200%; main action and empty guidance fit. Existing seven workspace cases pass. V synthetic task saved and selected. Existing filters retained; no invented data | Populated unusual/large lists, physical Tab/Narrator, shell brand wraps at 200% (P3 follow-up) |
| S02 task editor | U06/U07/U09; S/O/A/V draft→decline navigation→save. Ordinary/narrow inputs, identity and completion persisted | Rejected/stale saves with multiple drafts, OS close and physical IME/caret |
| S03 composition | S draft key includes checklist/subtask edits; O editor; A draft subtask and persisted checklist/real subtask. Separate prerequisite save is existing deliberate behavior | Populated dependency/reorder/error journeys; nested dirty subtask dismissal beyond save |
| S04 resources | S open/remove/unsafe-type/missing-file paths preserve external resources; O empty controls at 200%. Separate attachment copy versus external link retained | Native chooser/drop/relink, unavailable files, populated long labels on Android |
| S05 series/sequences/plans | S scope/sequence distinction retained; O empty sequence chooser at 200%; A recurring-collision scheduling refuses unreviewed Apply | Populated sequence reorder, future/end/skip and progressive-plan editing |
| S06 event editor | U08/U18; O/A 200% new form and start/end dates; actual close guard plus ordinary picker/category test | Populated recurrence/details/color, rejected save and all-day multi-date acceptance |
| S07 sessions | U08/U18; O/A new form/dates; guard; existing new/edit 300×600/150% light/dark actions. Outcome remains manual | Overlap/error/delete and physical date/time picker navigation |
| S08 desktop Calendar | U10; O/A day/week/month enlarged mode/full period and ordinary stable controls; V persisted task in Week | Dense overlapping entries, short day preview/context menus and physical keyboard |
| S09 mobile Calendar | S separate touch shell, counts omit duplicated task/session commitments; O/A 390×700/200% Week/empty day, 7-column cells and explicit add actions retained | Device month/day/rotation/Back, populated agenda and TalkBack |
| S10 organization | S category/project actions; A creation retains unsaved title/notes; category deletion cannot navigate through a declined draft guard | Project deletion equivalent source path inspected; category icon/color pickers and full restore journey |
| S11 search/saved views | S/O/A compact filters and result count; actual quick-result and saved-view navigation guarded. Inspection is not itself navigation | Large results, advanced result guard on a populated query, physical focus/keyboard |
| S12 templates | S/O empty manager; A opening/apply inspection preserves draft, denied Create writes nothing, accepted discard creates a new task. Definitions/history exclusions remain explicit | Project/routine apply, validation and deletion at large text |
| S13 scheduling | U11/U12/U17; S/O/A compact empty/history, preview, availability save, actual Apply/collision decision and close; V ordinary scheduling layout | Populated history restore/failure, all session operations and warning review at short heights |
| S14 habits | S/O/A empty overview and new editor at 200%; measurement/rest-day explanation retains domain distinction | Recorded values, correction/history/archive and validation feedback |
| S15 goals | S/O/A empty overview/new form; separate milestones/manual progress retained | Linked tasks, populated milestones/history, invalid values/archive |
| S16 focus/work | U15; S/O/A stopped→running→paused, persisted manual log regression; V start/pause/stop. Actual work remains distinct from task/session plans | Ownership handoff/checkpoint recovery, manual correction at large text |
| S17 reports | U14; S/O/A enlarged metrics/date/range plus ordinary persisted completion. No decorative chart/value rewrite | Populated long project names, custom-range cancel/invalid and nonzero work detail |
| S18 Archive/Trash | S/O/A empty Archive; source restore/permanent-delete safeguards and history retention inspected. Archive and Trash are distinct | Populated restore/purge/error and keyboard focus |
| S19 settings shells | S desktop section/menu and mobile sections; earlier compact mobile settings evidence reused; V Settings→Task Preferences→nested dialog | Complete nested mobile navigation, physical Back/Tab/focus return |
| S20 appearance | S/O/A 200% theme form; existing narrow light/dark changes pass; earlier V light/dark/restart evidence remains valid. Tokens/custom values preserved | Import/export/picker invalid/cancel with arbitrary custom palettes |
| S21 preferences/navigation | U13/U16; S/O/A real preference toggle/undo/Done and sidebar reorder; V toggle/undo. Existing immediate navigation preference test passes | Redo and restart of changed preferences; opening-page/calendar-content on device |
| S22 hotkeys | S/O/A search/preset/binding list at 200%; scoped keyboard controls retained | Rebind conflicts, reserved combinations, actual physical key dispatch |
| S23 notifications | S/O/A enlarged off/default controls and Save/Cancel layout; accurate Windows-companion requirement | Delivery, permissions, quiet hours, reboot/Doze and OS settings return |
| S24 privacy | S/O/A disabled PIN form at 200%; encryption limitation remains visible. Earlier lock/Sync closure passes reused | Actual PIN/Hello/biometric/idle/resume/Narrator/TalkBack |
| S25 startup/profile | S profile selection, migration approval and failure/retry paths; V actual isolated schema26 profile, no personal DB opened. Explicit no-reset recovery wording retained | Startup recovery uses non-scrolling columns: short-height/large-text reproduction is a pending risk, not a verified defect/fix. Isolated old-schema/failure UI required |
| S26 local backups | S/O/A unavailable-service parent and replacement confirmation at 200%; actual V profile safety established. Replacement wording/acknowledgment retained | Successful snapshot/import/restore/restart and interrupted/error states; no restore performed |
| S27 Drive backups | S/O/A disconnected/unavailable parent; separate snapshots versus Sync preserved | BLOCKED live account/OAuth/upload/download/recovery without disposable account configuration |
| S28 Sync status | Earlier source/widget/live evidence reused: no affected Sync presentation/controller/protocol change in this batch | Paired exchange/offline/reconnect remains BLOCKED; no repeated cloud operation |
| S29 private Sync | Earlier setup/unlock/validation/lock evidence reused unchanged | Actual protected-storage recovery on another device NOT TESTED |
| S30 Start New Sync | Earlier recovery disclosure, review/acknowledgment/cancel evidence reused unchanged | Real replacement/resume/cleanup NOT TESTED; no cloud destruction performed |
| S31 conflicts | Earlier compact/landscape/full-record/defer/no-implicit-apply evidence reused unchanged | Concurrent two-client propagation NOT TESTED |
| S32 settings transfer | S/O/A explanation/import/export/Close at 200%; portable preferences correctly distinguished from records/PIN/local paths | Chooser, merge preview, malformed/newer file and actual apply/reopen |
| S33 Windows updater | S/O/A ready state, installed version, channel/automatic-check layout at 200%; memory preferences disable network checks | Download/pause/retry/helper/install and release-note links; no installer run |
| S34 Android updater | S/O/A GitHub ready state at 200% with explicit fake sdk36/x64/version; store distribution distinctions inspected | Device permissions/install/Play action; no device, network or APK build |
| S35 Flutter widget settings | S/O/A both 520×650/200% Configure editors; Apply/Cancel/Apply-to-All labels fully inside viewport; Cancel causes zero writes | Offscreen captures intermittently omit footer despite passed bounds/tap assertions; render evidence is inconclusive for paint stability. Live native preview, preset library, Apply/all/close dirty journey remain |
| S36 native Tasks | S actual NativeDesktopWidgetHost/WidgetAccessibility (not just legacy LifeManagerWidget): named edit/complete/add actions, DPI/minimum/work-area handling, logical/pixel conversion | BLOCKED physical Explorer attachment, input, focus/UIA, menus, DPI/theme/empty/dense painting. No native code changed or rebuild performed |
| S37 native Calendar | S CalendarWidget layout/date/agenda hit-test/tooltip and shared native accessibility paths; date/agenda split is deliberate for density | BLOCKED physical splitter/wheel/menu/multi-monitor/accessibility; no new native pass claimed |
| S38 Android launcher widgets | S AndroidSurfaces bounded RemoteViews capacity measures actual font scale; contextual descriptions, explicit Open/add and one-use action token routes retained | BLOCKED device/launcher/OEM/locked/reboot/rotation/TalkBack; no native Kotlin/XML change |
| S39 support/contributors | S/O/A both at 200%; optional support text retained; synthetic browser failure remains visible with enabled retry. Official destinations/registry unchanged; no real external link opened | Real browser/email return and focus. No messages/payment/network action sent |
| S40 shared overlays/input | S/O/A shared selector, discard, action bar, date/time consumers; local spelling generation/disposal inspected. Reuse existing components and theme roles | Actual IME/composition, spelling popup, color/icon/native pickers, reduced motion/high contrast/RTL and screen readers |

No group is certified complete across every requested dimension. The scoped fixes
above are completed implementation work; populated advanced journeys and physical
platform acceptance remain explicit. The inventory's 67-category applicability
mapping still applies; this pass does not turn unexecuted combinations into passes.

### Runtime and tooling receipt, continuation

At 09:26:41+03:00 launched the owned Debug/Driver app with
`flutter --no-version-check --suppress-analytics run --no-pub -d windows --target lib/driver_main.dart --machine`
under `pass2/runtime-profile/{Roaming,Local}`. `runtime-launch.json` records the
launcher PID27188; VM identifies actual Todorbit PID16636. Before input, VM
evaluation confirmed both child environment paths; Drift's resolved database was
`Roaming/TodoPilot/life_manager.sqlite`, schema26, `quick_check=ok`, zero tasks.
This differs from the personal installed process and no personal window/profile
was selected. Tests use memory SQLite and the runner's disposable profile paths.

Live Driver journey: empty Today→new title→Calendar→Discard prompt→Keep editing→
same title→Create→Calendar Week shows synthetic task. Settings→Task Preferences→
toggle→Undo→Done. All tasks→Reschedule→Generate preview→Cancel (no Apply).
Task details→Actual work and timer→start→pause→stop→close. Observed ordinary
Windows visuals, saved synthetic task, feedback and zero reported runtime errors.
Successful hot reloads cover the implementation changes; latest reload after the
new date/time component also passed. Live 200% scaling was not injected.

Saved Driver evidence: `guard-runtime-shot.png`, `pass2-calendar-shot.png`,
`pass2-settings-live.png`, `pass2-scheduling-live.png`, `pass2-focus-live.png`,
`pass2-focus-paused-live.png`. Offscreen `renders/` includes all 31 secondary
states and corrected scrolled event/session date views. Segoe text is loaded for
host geometry; missing offscreen Material icon glyphs remain a fixture limitation,
not a claimed product icon defect (ordinary live Windows glyphs render).

Computer-use entry `sky.list_windows()` failed because its native pipe was absent
(`os error 2`); Driver fallback was used. A VM window resize attempt failed
(`windowManager` is not imported in that evaluation library); no physical resize
occurred. `Get-Command adb` found no executable on PATH; no Android device session
was used. These block physical evidence, not the independent widget assertions.
Three wrong Driver finders for `Actual work` timed out; source's actual text is
`Actual work and timer`; scrolling its ListView and using that target succeeded.
Screenshot persistence via a shell-quoted Python `-c` failed before writing due
Windows argument quoting; bounded Node file writes then saved all six PNGs.

Dart MCP analysis first returned no roots; explicitly added this project root.
Analysis of the 12 initial affected paths returned **No errors**, then analysis of
the eight additional/updated scheduling/report/timer/date/sidebar/test paths also
returned **No errors**. The latter took ~26 seconds; no duplicate CLI analysis or
unnecessary full test/build run followed. Test invocation details follow.

### Verification reuse and final review, continuation

51 newly added cases (13 draft navigation, five main-surface, 31 secondary-surface,
two scheduling-warning) have valid passes across the receipts below, supplemented
by the explicitly selected existing regressions. This is not a fresh full-suite
pass. Reuse unchanged cases after each focused correction: initial secondary
passes are replaced only for the seven corrected layout/readability samples;
new editor samples only for the corrected date assertions; warning-wide pass is
reused after the compact test's lazy-scroll correction. Final test formatting
changes no assertions or product logic. New shared DateTimeButtonRow remained
unchanged after its initial formatting; the final manifest supplements early
runner manifests that did not include an untracked dependency automatically.

Earlier Sync, skill metadata/67-category/local-reference and instruction-routing
passes remain valid: those files, assertions, dependencies and relevant settings
are unchanged. No PyYAML dependency installation, full host-suite rerun, release
build, APK, installer, native rebuild/self-test or live cloud operation was
justified by this presentation checkpoint. Native/manual/device gates remain
required for their affected changes or release; they are not waived or passed.

Final MCP analysis after the Calendar/test edits returned No errors for those
three paths; the restored warning layout and its regression file likewise
returned No errors. `checkpoint-docs-100813.json/log` records zero documentation
link/path errors. Later additions are receipt prose and invocation rows only;
validated link/anchor targets remain unchanged, so no repeat is needed.

`python .buildlog/verify/permanent-ui-quality/pass2/final-review.py` checks the
22-file task allowlist, full diff whitespace and unrelated-document hashes,
including untracked new task code/tests, and writes `pass2/final-review.json`.
Initial pre-stage run at 10:09+03 and final staged receipt refresh agree on
production code. All three original unrelated documents match byte for byte.
Read-only inspection of the owned runtime profile confirms schema26,
`quick_check=ok`, exactly the named synthetic task/date and one stopped timer.
The final RPC `ext.flutter.exit` intentionally disposed its connection; process
inspection confirms owned PID16636 stopped and personal installed PID21876
still running. No personal window/profile or native companion was operated.

The local commit contains this completed, verified implementation batch and its
checkpoint, not all outstanding acceptance in the 40-group table. Source/diff
review, explicit staging and `git diff --cached --check` are required before
commit; no push, release, tag or version operation is authorized/performed.

### Exact invocation ledger, continuation

All times below are 2026-11-04 **UTC+03:00**, source `c32329c` plus each
invocation's recorded dirty-file SHA-256. Logs/JSON are in ignored
`.buildlog/verify/permanent-ui-quality/pass2/`; the basename in each row identifies
both files. These are individual executions, not one fresh all-tests pass.

Command substitutions are literal, preserving argument order:

- `F` = `flutter --no-version-check --suppress-analytics test --no-pub --concurrency=1 --reporter=expanded`.
- `W` = `test/workspace_draft_safety_test.dart`; `H` = `test/high_use_ui_quality_test.dart`; `S` = `test/secondary_surface_quality_test.dart`.
- Table `\|` is only a Markdown escape: the regex argument contains an ordinary `|`.
- From `secondary-fixes-direct`, the wrapper invokes the existing SDK's
  `dart.exe flutter_tools.snapshot` with these exact Flutter arguments to avoid
  Windows batch-shell regex parsing. `actualCommand` records the full executable
  paths; no SDK/package/dependency was installed or changed.
- Each test uses memory SQLite; disposable child APPDATA/LOCALAPPDATA redirects
  are recorded per invocation. Initial draft-only runs needed no profile-backed
  services. No test used personal data. Formatting receipts record input hashes;
  final review records output hashes, including the new shared component.

| Time / receipt basename | Exact command (substitutions above) | Result / necessity or rerun cause |
| --- | --- | --- |
| 09:14:13 / `draft-before-091413` | `F W` | Exit 1. Baseline: 5 failures, including one ambiguous New task finder; remaining cases reproduce draft loss. |
| 09:17:19 / `draft-format-091719` | `dart format lib/features/workspace/workspace.dart lib/features/workspace/task_editor.dart lib/features/workspace/quick_search.dart lib/features/search/advanced_search_dialog.dart W` | Exit 0. Format new draft/navigation implementation and test. |
| 09:17:22 / `draft-after-091722` | `F W test/workspace_test.dart` | Exit 1. 10 pass, 2 fail: New task finder and Escape before PopScope rebuilt. Existing workspace seven pass. |
| 09:19:39 / `high-use-before-091939` | `F H W` | Exit 1. Five draft cases pass; high-use file fails to compile: missing app-theme import. Corrected import only. |
| 09:20:13 / `high-use-probe-092013` | `F H` | Exit 1. Two widget-editor cases pass; Today harness plugin failure, missing completion semantics and clipped Week are diagnosed separately. |
| 09:21:25 / `high-use-after-092125` | `F H --name 'Today\|completion semantics\|Calendar mode'` | Exit 0. Three pass after corrected standalone Workspace harness, semantics and intrinsic mode labels. |
| 09:23:40 / `batch2-format-092340` | `dart format lib/features/workspace/workspace.dart lib/features/workspace/task_editor.dart lib/features/workspace/quick_search.dart lib/features/search/advanced_search_dialog.dart lib/features/templates/templates_dialog.dart lib/features/calendar/calendar_view.dart lib/features/mobile/mobile_workspace.dart W H` | Exit 0. Format batch source and expanded regressions; no behavioral test repeated for formatting. |
| 09:25:02 / `guard-checks-092503` | `F W` | Exit 1. 9 pass; Work session Upcoming finder ambiguous with sidebar. Limit corrected rerun to that case. |
| 09:29:32 / `secondary-probe-092933` | `F --timeout=2m S` | Exit 1. 22 pass, 3 fail: scheduling overflow, availability overflow, preferences intrinsic-layout exception. New compact surface coverage. |
| 09:34:05 / `scheduling-format-093405` | `dart format lib/features/scheduling/smart_reschedule.dart` | Exit 0. Format confirmed scheduling layout fix. |
| 09:34:30 / `settings-format-093430` | `dart format lib/features/settings/task_view_settings_dialog.dart S W` | Exit 0. Format confirmed preferences fix and corrected test finders. |
| 09:34:33 / `secondary-fixes-093433` | `F --timeout=2m S --name 'S13-reschedule\|S13-availability\|S21-task-preferences'` | Exit 255. Exit255 before tests: Windows cmd interpreted unquoted regex pipes. Runner now uses SDK Dart/Flutter snapshot directly. |
| 09:35:03 / `secondary-fixes-direct-093503` | `F --timeout=2m S --name 'S13-reschedule\|S13-availability\|S21-task-preferences'` | Exit 0. Three pass after runner quoting correction; same failing product cases only. |
| 09:39:14 / `actions-format-093915` | `dart format lib/features/scheduling/smart_reschedule.dart S` | Exit 0. Format compact scheduling title and additional persisted-state assertions. |
| 09:39:18 / `focused-regressions-093918` | `F S W test/smart_reschedule_widget_test.dart test/settings_ui_quality_test.dart test/calendar_improvements_test.dart test/mobile_workspace_test.dart --name 'S13-reschedule\|S13-availability\|S21-task-preferences\|desktop Calendar Work session\|Smart Reschedule\|theme and task preferences\|calendar controls stay\|new task protects Back edits\|mobile task completion'` | Exit 0. 11 pass: compact scheduling/availability/preferences actions, corrected Work session finder, scheduler Apply/collision, both settings themes, Calendar and mobile. Existing collision-label tap emits nonfatal hit-test warning; actual choice and persisted Apply assertions pass. |
| 09:41:32 / `navigation-format-094132` | `dart format lib/features/workspace/workspace.dart W` | Exit 0. Format saved-view/category/project guard and new integration assertions. |
| 09:41:34 / `navigation-actions-094134` | `F W --name 'creating a saved view\|template inspection\|category deletion'` | Exit 1. Three fail: lazy sidebar targets not built and wrong Discard text in new tests. Source guards are not blamed for finder failures. |
| 09:42:25 / `navigation-actions-corrected-094225` | `F W --name 'creating a saved view\|template inspection\|category deletion'` | Exit 1. Template and category cases pass. Saved-view target reached but tap preceded final scroll layout; add settle. |
| 09:43:15 / `saved-view-settled-094315` | `F W --plain-name 'creating a saved view guards the desktop draft before saving'` | Exit 0. Saved-view case passes after ensureVisible plus settle; no product retry or duplicate write. |
| 09:45:57 / `remaining-form-probe-094557` | `F S --name 'S02-S03\|S04-resources\|S06-event\|S07-session\|S09-mobile\|S39-support'` | Exit 0. Six new compact editor/resource/mobile-Calendar/support samples pass. No native pickers or external links operated. |
| 09:47:15 / `final-format-094715` | `dart format lib/features/calendar/calendar_view.dart lib/features/mobile/mobile_workspace.dart lib/features/scheduling/smart_reschedule.dart lib/features/search/advanced_search_dialog.dart lib/features/settings/task_view_settings_dialog.dart lib/features/templates/templates_dialog.dart lib/features/workspace/quick_search.dart lib/features/workspace/task_editor.dart lib/features/workspace/workspace.dart H S W` | Exit 0. Format current 12-file scope; only test formatting changed. |
| 09:48:12 / `composition-organization-094812` | `F test/task_composition_widget_test.dart test/round3_editor_test.dart --name 'draft subtask dialog\|task details add\|task editor keeps unsaved'` | Exit 0. Three pass: draft subtask, actual checklist/subtask and draft-preserving organization. Required for enabled nested guard/shared TaskEditor. |
| 09:48:22 / `support-failure-094822` | `F S --plain-name 'S39-support compact enlarged state retains usable layout'` | Exit 0. One pass after adding browser-failure/retry assertion; stub throws, no browser or payment opened. |
| 09:50:04 / `reports-focus-before-095004` | `F S --name 'S16-focus\|S17-reports'` | Exit 1. Two new readability assertions fail as observed: split metric word and wrapped time. Earlier no-overflow passes do not prove readability. |
| 09:51:14 / `names-before-095114` | `F S --name 'S21-sidebar\|S13-history'` | Exit 1. Two new assertions fail as observed: compressed sidebar name and split history heading. |
| 09:52:13 / `readability-format-095213` | `dart format lib/features/reports/reports_view.dart lib/features/time_tracking/time_tracking_dialog.dart lib/features/settings/sidebar_order_dialog.dart lib/features/scheduling/smart_reschedule.dart S` | Exit 0. Format four confirmed readability fixes and strengthened tests. |
| 09:52:15 / `readability-after-095215` | `F S --name 'S16-focus\|S17-reports\|S21-sidebar\|S13-history'` | Exit 1. Compile failure: report width inferred num. Corrected literals to double; no test passes claimed. |
| 09:52:36 / `readability-typed-095236` | `F S --name 'S16-focus\|S17-reports\|S21-sidebar\|S13-history'` | Exit 0. Four pass after type correction: history, focus, reports, sidebar readability. |
| 09:53:46 / `date-values-before-095346` | `F S --name 'S06-event-editor\|S07-session-editor'` | Exit 1. Two new date-value assertions fail as observed in Event and Session at 200%. |
| 09:54:49 / `date-actions-format-095449` | `dart format lib/features/shared/date_time_button_row.dart lib/features/calendar/event_editor.dart lib/features/calendar/session_editor.dart S` | Exit 0. Format shared responsive date/time component, both callers and action assertions. |
| 09:54:51 / `final-journey-checks-095452` | `F S test/reports_widget_test.dart test/time_tracking_widget_test.dart test/calendar_improvements_test.dart test/session_editor_layout_test.dart test/event_editor_layout_test.dart --name 'S06-event-editor\|S07-session-editor\|S16-focus\|S17-reports\|S21-sidebar\|S13-history\|reports show persisted\|actual work dialog starts\|sidebar order controls\|new and edit session actions\|event form keeps'` | Exit 0. 11 pass: corrected dates/readability plus persisted report, timer/manual log, reorder and ordinary/narrow editor regressions. |
| 09:57:48 / `date-render-confirmation-095748` | `F S --name 'S06-event-editor\|S07-session-editor'` | Exit 0. Two pass; added scrolled date captures to inspect correction beyond top-of-form frames. |
| 09:59:05 / `calendar-widget-geometry-095905` | `F H --name 'Calendar mode\|widget customization'` | Exit 1. Both widget editors pass stronger whole-action bounds/Cancel checks. New Calendar full-period assertion fails at 240 versus 257.04px. |
| 09:59:51 / `calendar-period-after-095951` | `F H test/calendar_improvements_test.dart --name 'Calendar mode\|calendar controls stay in place'` | Exit 1. New period assertion passes; ordinary stable-control regression fails because intrinsic period width moves controls. Retain regression; replace with text-scaled reserved width. |
| 10:02:32 / `calendar-period-stable-100232` | `F H test/calendar_improvements_test.dart --name 'Calendar mode\|calendar controls stay in place'` | Exit 0. Both pass after preserving fixed width per text scale across modes. No unchanged widget cases repeated. |
| 10:03:36 / `checkpoint-format-100336` | `dart format lib/features/calendar/calendar_view.dart lib/features/calendar/event_editor.dart lib/features/calendar/session_editor.dart lib/features/mobile/mobile_workspace.dart lib/features/reports/reports_view.dart lib/features/scheduling/smart_reschedule.dart lib/features/search/advanced_search_dialog.dart lib/features/settings/sidebar_order_dialog.dart lib/features/settings/task_view_settings_dialog.dart lib/features/shared/date_time_button_row.dart lib/features/templates/templates_dialog.dart lib/features/time_tracking/time_tracking_dialog.dart lib/features/workspace/quick_search.dart lib/features/workspace/task_editor.dart lib/features/workspace/workspace.dart H S W` | Exit 0. 18 files formatted; only high-use test formatting changed. Reuse relevant prior behavior passes. |
| 10:05:47 / `wide-warning-before-100547` | `F test/smart_reschedule_widget_test.dart --plain-name 'scheduling warnings remain reviewable before Apply (compact=false)'` | Exit 1. New review regression fails: compact refactor put wide warning acknowledgment below the visible pane. Restore original wide placement; retain gate. |
| 10:06:28 / `warning-format-100628` | `dart format lib/features/scheduling/smart_reschedule.dart test/smart_reschedule_widget_test.dart` | Exit 0. Format restored wide warning placement and two review-gate regression cases. |
| 10:06:30 / `warning-approval-after-100630` | `F test/smart_reschedule_widget_test.dart --plain-name 'scheduling warnings remain reviewable before Apply'` | Exit 1. Wide case passes after restoring footer placement. Compact test fails to find lazily built acknowledgment before scrolling; correct test navigation, not approval logic. |
| 10:07:28 / `compact-warning-scroll-100728` | `F test/smart_reschedule_widget_test.dart --plain-name 'scheduling warnings remain reviewable before Apply (compact=true)'` | Exit 0. Compact case passes after scrollUntilVisible then ensureVisible. Preview remains non-mutating, Apply requires explicit review, and actual date/history persist. Reuse wide pass. |
| 10:08:12 / `warning-final-format-100812` | `dart format test/smart_reschedule_widget_test.dart` | Exit 0. Format corrected lazy-scroll test; no production changes or behavioral rerun. |
| 10:08:13 / `checkpoint-docs-100813` | `python tools/dev/check-docs.py docs/PROGRESS.md docs/TEST_RUN_LEDGER.md docs/UI_UX_PERMANENT_QUALITY_AUDIT.md` | Exit 0. Scoped documentation links/path validation after ledger and checkpoint edits; result is the recorded exit code. |
