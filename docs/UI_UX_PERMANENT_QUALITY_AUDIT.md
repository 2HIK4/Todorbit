# Permanent UI quality: audit and implementation — 2026-11-04

Baseline `25874c0`, branch `feature/permanent-ui-quality`. Audit + implementation,
no publication/commit requested. Existing storage documentation changes in
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
