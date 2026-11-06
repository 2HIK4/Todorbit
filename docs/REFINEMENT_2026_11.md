# Sync and cross-platform refinement (2026-11-05/06)

Baseline: `501e748`, branch `feature/sync-ux-refinement`. Unrelated dirty
`docs/DEVELOPMENT.md`, `docs/STORAGE_CLEANUP_2026_11_04.md` and
`docs/STORAGE_MAINTENANCE.md` are preserved and excluded from commits.

Implementation order: causal deletion correctness and conflict disclosure;
data relationships; shared filters/list hierarchy; editor creation parity;
navigation/settings; native widget date controls; integration verification.
Keep actual cloud acceptance separate from deterministic two-profile tests.
No production profile, cloud content, release version or publication is changed.

## Diagnosis and safety

Normal repository/native reads already exclude soft-deleted records. Purge
tombstones and recurrence occurrence slots are retained. Causal heads, immutable
operation IDs, complete mutation groups, account/workspace pinning, replay checks,
and transactional application protect offline/repeated exchanges. Snapshot
restore replaces a reviewed database at restart, retains Before Restore, and
quarantines Sync pending explicit reconciliation. An old snapshot's absence
does not delete cloud-only records. Standard and Private use the same merge path.

Confirmed code-level risk: concurrent soft deletions of otherwise identical
records are treated as different whole-record choices solely because deletion
timestamps differ. Concurrent archive/edit and delete/edit remain meaningful
decisions. The user's actual unexpected records remain unproven without an
isolated reproduction; no personal database or cloud workspace is inspected.

Separate display defects were reproduced with synthetic data: a distant Calendar
window could empty Today's event projection, and explicit occurrence category,
color, icon or reminder clearing could fall back to series values. Today now
loads its own bounded range when needed; overrides distinguish absent legacy keys
from explicit nulls. Flutter and native projections preserve those distinctions.

## Implemented behavior and capability review

The canonical UI skill and Todorbit tokens govern this Windows/Android pass;
Apple guidance is supplementary. No package dependency, release version,
production account, user profile, workspace proof or encryption key is changed.

| Request | Implementation / boundary |
| --- | --- |
| Deletion and Sync | Equivalent concurrent soft deletions coalesce only when every other user value agrees. All heads/history remain; delete/edit, restore/edit and archive/edit still require safe causal decisions. No tombstone compaction. |
| Conflict decisions | Compact entity/title/difference/action cards; expandable values, source, timestamps, prior values and complete records. Compatible internal rows are omitted from decisions. Counted bulk actions retain confirmation. Device-only selections persist against the exact review fingerprint; stale candidates are rejected. |
| Add/Edit | Common fields remain visible; notes, organization, composition and resources disclose on demand. Goal creation can select existing task/project/habit links. Existing immediate-save relationship/resource controls say so. See capability matrix. |
| Event projects | Optional project relation validated with its category, including recurring occurrence exceptions and future-series splits. Project/category/saved views, search, Calendar, Sync and snapshots retain it. |
| Filters | Shared filter control/chips in Today, All Tasks, Calendar and scoped task/event lists; category, project, task statuses, minimum task priority, recurrence and inclusive date range. Individual removal and Clear All. Session filtering follows matching task IDs. |
| Categories/navigation | Remembered category disclosure; optional built-ins and saved views can be hidden. Keyboard-accessible reorder and Restore Defaults. Custom entries reuse named saved filters, including category/project combinations. Settings/customization stay reachable; Android uses its drawer. |
| Recurrence/subtasks | All Tasks groups actual recurrence family/series IDs, with next occurrence and expandable states. Default groups include closed related occurrences; active filters constrain results. Parent-present children nest; matching children remain independent when filters exclude their parent. Today/Calendar retain date-specific occurrences. |
| Windows widgets | Tasks Today and Calendar gain previous/next day and Today actions with accessible names. Native per-host selection, midnight following, selected-day quick add and compact geometry; existing companion/process/profile boundaries retained. |
| Android widgets | Per-widget date preference and immutable, explicit broadcast actions navigate a cached 14-day range on either side of the projection date. Calendar week cells select dates. Today follows local date when no explicit date is stored. No new polling. |
| Android home/support | Decorative focus card replaced by a compact real completion line. Support moves to the drawer; distribution capability still chooses donation versus non-payment project support. |
| Android Settings | Five grouped sections: Appearance; Planning and navigation; Notifications and privacy; Data and app; About. Existing controls and recovery warnings remain. |
| Scroll/spacing/design | Shared pointer-transparent top/bottom hints appear only with remaining extent, suppress nested stacking and rebuild only on edge changes. Existing semantic type, surface, spacing, border and palette tokens remain authoritative; redundant section dividers removed. |
| Motion | Enabled by default through the existing preference, presented as Interface animations. Short shared dialog/sheet/disclosure transitions; disabled preference and system reduced motion bypass decorative transitions. Native OS pickers/launcher behavior remain OS-owned. |

### Add versus Edit capability matrix

| Entity / workflow | Creation | Editing / rationale |
| --- | --- | --- |
| Task | Title, planned day/deadline, priority/status, notes, category/project, estimates, reminders, prerequisites, icon, draft resources, named checklists and full subtasks | Same relevant fields; existing resources/checklists/subtasks save independently and are labeled. Stored recurrence has a separate scope-aware series editor. |
| Subtask | Shared task editor, resources and named checklists; parent identity retained | Shared task editor. Nested full subtasks remain unavailable under the existing one-level hierarchy rule; checklist items remain distinct. |
| Recurring task | Rule/progressive plan plus task fields; composition/resources attach to the first occurrence, explicitly explained | Occurrence actions, skip/history and separate series scope preserved; recipes are not silently copied to every occurrence. |
| Event | Title, fixed time/all-day, notes/custom details/location, category/project/color/icon, repeat/reminder | Same fields, plus existing occurrence/future/series scope. Optional project can be cleared. |
| Goal | Title, description, target/unit, start/deadline, selected task/project/habit links | Same goal fields; established link and milestone actions remain available. Progress/milestones require a saved identity and real activity. |
| Habit | Title, conditional target/unit, notes, schedule/dates, rest-day behavior | Same fields with existing preserve-history schedule warning; logs require a saved habit/date. |
| Category/project | Existing compact name, category relationship, icon/color controls | Same fields and existing archive/delete safeguards; no artificial advanced sections added to short forms. |
| Checklist/group | Draft multiple groups/items, edit/order/remove before task save | Named group rename/order/remove with reviewed child revisions; item completion is separate from task completion. Legacy ungrouped items retained. |
| Work session | Shared task, fixed start/end and explicit outcome controls | Same fields; actual work and planned duration remain separate. |
| Saved view/custom entry | Existing live filter engine, display name and sort; zero-match view allowed | Rename/filter update, hide, reorder and remove through established saved-view actions. Unavailable references never silently become another category/project. |
| Milestone, progressive plan, sequence, template, custom event detail | Existing focused editors with shared action/unsaved validation patterns | Existing update controls preserved; template composition/resources remain with their source, not falsely portable recipes. |

### Filter and window semantics

Different filter dimensions combine with AND. Selected task statuses combine
with OR. Category/project are single selections; project choices follow category.
Priority is a minimum. Date bounds include both endpoints: tasks use **planned
day**, events overlap local calendar days. Event status/priority controls do not
exist because events have neither task status nor task priority. Task-only saved
criteria do not invent those fields on events. Counts derive from the filtered
projection. Filtering never writes task/event data.

Ad-hoc filters survive in-session navigation within the same view and
category/project/saved-view identity; unrelated routes have separate state.
Named custom entries persist through the existing saved-view store; Customize
navigation can remove an entry with explicit confirmation while keeping items. Event search
and scoped lists use the loaded Calendar occurrence window, not an unlimited
history query. Visible event-window labels make that scope explicit; mobile
inline search also includes events and assignment names. Opening a project
event directly preserves the project destination. Today retains a current-day
projection when Calendar browses a distant month, sharing the window query when
it already includes today. Recurrence materialization remains bounded by existing policies.

### Compatibility and recovery

Schema 27 adds nullable `fixed_events.project_id`, named checklist groups and
nullable item membership. The schema-26 upgrade installs only additive DDL and
updated capture triggers: it does not replay old migrations over immutable
journals. Old record shapes receive null defaults only in the semantic merge
projection/final SQL write, never in journal identity or encrypted queued bytes.
Schema-27 clients accept schema-26 batches; old clients safely refuse schema-27
batches, so update every connected device before using the new relationships.
The workspace proof/encryption format remains schema 26 deliberately. Compatible
26/27 Before Restore history tables retain their original bytes; prototype
23-25 history still requires reviewed conversion.

Snapshot backups contain SQLite rows, managed attachment bytes and relationships.
The existing embedded widget-personalization bundle is retained too.
External file/folder links remain device-local references. Device preferences
remain profile JSON, with explicit shareable settings transfer; a database-only
snapshot must not be described as all machine preferences. Navigation settings
transfer now includes hidden/custom order/category disclosure. Restores retain
preview/validation, Before Restore, atomic replacement and Sync quarantine;
explicit restored-state reconciliation never infers deletions from absence.

### Platform limits and human acceptance

Android uses RemoteViews rather than a live Flutter widget. It preserves existing
API-31 exact-size and older orientation variants, immutable PendingIntents and
cached repository projection. This follows Android's documented
[interactive update model](https://developer.android.com/develop/ui/views/appwidgets/advanced)
and [flexible layouts](https://developer.android.com/develop/ui/views/appwidgets/layouts).
The cached range is bounded; 500 tasks/100 agenda entries remain the existing
capacity limits, now explicitly flagged when truncated. Open Todorbit to refresh
or see the full list. Date controls do not perform SQLite or cloud work.

Native Windows Computer Use initialization in this session failed with
`failed to write kernel assets ... path ... (os error 3)`. No native interaction
pass is claimed. The retained Android API35 acceptance AVD previously failed
separated system-service health checks; no unchanged emulator is repeatedly
booted to manufacture evidence. Physical launcher, OEM/ARM64, IME/Back, TalkBack,
Narrator, shell attachment, multiple monitors/DPI and live Drive remain explicit
acceptance tasks in [the platform checklist](UI_UX_PLATFORM_ACCEPTANCE.md).


## UI review coverage

Mode: implementation, diagnosis and polish across Windows/Android task/event
lists and editors, navigation, settings, conflict/recovery journeys and both
native widgets. This is a comprehensive **scope review**, not a claim that every
screen/device permutation has been physically tested. Source review checks both
correctness and usability: common actions stay visible; optional metadata uses
labeled disclosure; data-loss choices retain explicit review; short category and
project name forms stay short. Internal protocol vocabulary and raw records stay
in expanded diagnostic detail. Existing recovery warnings remain because they
change the user's decision.

Seven coverage dimensions: surfaces/owners are mapped above; platform is
Windows 10/11 and Android (iOS/web excluded); data includes empty, populated,
long text, recurrence, linked and deleted records; states include draft, pending,
failure, stale and restart; input includes automated pointer/keyboard and
simulated mobile Back; appearance includes light/dark, custom tokens, RTL and
large text where existing/new cases apply; lifecycle includes save/cancel,
navigate, replay, backup/restore and restart. Full physical cross-products remain
open; test results below establish only their named assertions.

Every canonical inventory row was assessed for applicability. `Inspected` means
source/experience review, **not** a universal passing test. Targeted and serial
results below supply scoped automated evidence. Native/OS readers, physical
inputs and real cloud behavior remain separate acceptance rows.

| # / category | Applicability and review boundary | Remaining evidence limit |
| --- | --- | --- |
| 1. User goals and mental models | Inspected: common actions, disclosure, naming, navigation and safe exits | New-user physical walkthrough open |
| 2. Workflow complexity and unnecessary steps | Inspected: common actions, disclosure, naming, navigation and safe exits | New-user physical walkthrough open |
| 3. Information architecture | Inspected: common actions, disclosure, naming, navigation and safe exits | New-user physical walkthrough open |
| 4. Discoverability and affordances | Inspected: common actions, disclosure, naming, navigation and safe exits | New-user physical walkthrough open |
| 5. Onboarding and first-time experience | Inspected: common actions, disclosure, naming, navigation and safe exits | New-user physical walkthrough open |
| 6. Cognitive load and information overload | Inspected: common actions, disclosure, naming, navigation and safe exits | New-user physical walkthrough open |
| 7. Content, labels and microcopy | Inspected: common actions, disclosure, naming, navigation and safe exits | New-user physical walkthrough open |
| 8. Navigation and wayfinding | Inspected: common actions, disclosure, naming, navigation and safe exits | New-user physical walkthrough open |
| 9. User control and freedom | Inspected: common actions, disclosure, naming, navigation and safe exits | New-user physical walkthrough open |
| 10. Trust, expectations and transparency | Inspected: common actions, disclosure, naming, navigation and safe exits | New-user physical walkthrough open |
| 11. Visual hierarchy | Inspected: existing semantic tokens, compact groups, readable differences and density | Live light/dark/custom visual variants remain scoped |
| 12. Typography | Inspected: existing semantic tokens, compact groups, readable differences and density | Live light/dark/custom visual variants remain scoped |
| 13. Spacing and padding | Inspected: existing semantic tokens, compact groups, readable differences and density | Live light/dark/custom visual variants remain scoped |
| 14. Alignment, grids and geometry | Inspected: existing semantic tokens, compact groups, readable differences and density | Live light/dark/custom visual variants remain scoped |
| 15. Color and contrast | Inspected: existing semantic tokens, compact groups, readable differences and density | Live light/dark/custom visual variants remain scoped |
| 16. Themes and appearance customization | Inspected: existing semantic tokens, compact groups, readable differences and density | Live light/dark/custom visual variants remain scoped |
| 17. Icons, symbols and imagery | Inspected: existing semantic tokens, compact groups, readable differences and density | Live light/dark/custom visual variants remain scoped |
| 18. Cards, surfaces, borders and shadows | Inspected: existing semantic tokens, compact groups, readable differences and density | Live light/dark/custom visual variants remain scoped |
| 19. Content density and screen balance | Inspected: existing semantic tokens, compact groups, readable differences and density | Live light/dark/custom visual variants remain scoped |
| 20. Design systems and consistency | Inspected: existing semantic tokens, compact groups, readable differences and density | Live light/dark/custom visual variants remain scoped |
| 21. Buttons and action controls | Inspected: form identity, validation, selectors, edge hints, filters and grouped lists | Automated interactions below; physical keyboard/picker open |
| 22. Forms and data entry | Inspected: form identity, validation, selectors, edge hints, filters and grouped lists | Automated interactions below; physical keyboard/picker open |
| 23. Validation and error prevention | Inspected: form identity, validation, selectors, edge hints, filters and grouped lists | Automated interactions below; physical keyboard/picker open |
| 24. Dependent inputs and logical relationships | Inspected: form identity, validation, selectors, edge hints, filters and grouped lists | Automated interactions below; physical keyboard/picker open |
| 25. Dropdowns, menus and selectors | Inspected: form identity, validation, selectors, edge hints, filters and grouped lists | Automated interactions below; physical keyboard/picker open |
| 26. Dialogs, modal windows and bottom sheets | Inspected: form identity, validation, selectors, edge hints, filters and grouped lists | Automated interactions below; physical keyboard/picker open |
| 27. Scroll behavior and layout stability | Inspected: form identity, validation, selectors, edge hints, filters and grouped lists | Automated interactions below; physical keyboard/picker open |
| 28. Focus management and keyboard behavior | Inspected: form identity, validation, selectors, edge hints, filters and grouped lists | Automated interactions below; physical keyboard/picker open |
| 29. Status messages and feedback | Inspected: form identity, validation, selectors, edge hints, filters and grouped lists | Automated interactions below; physical keyboard/picker open |
| 30. Loading, empty, offline and failure states | Inspected: form identity, validation, selectors, edge hints, filters and grouped lists | Automated interactions below; physical keyboard/picker open |
| 31. Selection, bulk operations and drag-and-drop | Inspected: form identity, validation, selectors, edge hints, filters and grouped lists | Automated interactions below; physical keyboard/picker open |
| 32. Search, filtering and sorting | Inspected: form identity, validation, selectors, edge hints, filters and grouped lists | Automated interactions below; physical keyboard/picker open |
| 33. Lists, tables, trees and collections | Inspected: form identity, validation, selectors, edge hints, filters and grouped lists | Automated interactions below; physical keyboard/picker open |
| 34. Calendars, timelines and scheduling interfaces | Inspected: form identity, validation, selectors, edge hints, filters and grouped lists | Automated interactions below; physical keyboard/picker open |
| 35. Task management and productivity workflows | Inspected: form identity, validation, selectors, edge hints, filters and grouped lists | Automated interactions below; physical keyboard/picker open |
| 36. Responsive and adaptive layouts | Inspected: responsive constraints, text/RTL semantics and reduced motion | Named widget sizes/themes only; no universal accessibility claim |
| 37. Mobile-specific interface issues | Applicable: native/platform integration inspected | Host/native tests below; physical OS/reader/OEM acceptance open |
| 38. Windows and desktop-specific interface issues | Applicable: native/platform integration inspected | Host/native tests below; physical OS/reader/OEM acceptance open |
| 39. Web-specific interface issues, where applicable | N/A: no supported web release | No browser claim |
| 40. Keyboard, mouse, touch and alternative inputs | Applicable: native/platform integration inspected | Host/native tests below; physical OS/reader/OEM acceptance open |
| 41. Accessibility and visual perception | Inspected: responsive constraints, text/RTL semantics and reduced motion | Named widget sizes/themes only; no universal accessibility claim |
| 42. Accessibility semantics and assistive technology | Applicable: native/platform integration inspected | Host/native tests below; physical OS/reader/OEM acceptance open |
| 43. Localization, internationalization and RTL | Inspected: responsive constraints, text/RTL semantics and reduced motion | Named widget sizes/themes only; no universal accessibility claim |
| 44. Animations and transitions | Inspected: responsive constraints, text/RTL semantics and reduced motion | Named widget sizes/themes only; no universal accessibility claim |
| 45. Widgets, extensions and secondary interfaces | Applicable: native/platform integration inspected | Host/native tests below; physical OS/reader/OEM acceptance open |
| 46. Notifications, badges and system alerts | Applicable: native/platform integration inspected | Host/native tests below; physical OS/reader/OEM acceptance open |
| 47. UI state management | Inspected: state/persistence, causal decisions, local-first recovery and identity | Deterministic two-device tests; live Drive unauthorized/unverified |
| 48. Settings and personalization | Inspected: state/persistence, causal decisions, local-first recovery and identity | Deterministic two-device tests; live Drive unauthorized/unverified |
| 49. Cloud synchronization and multi-device behavior | Inspected: state/persistence, causal decisions, local-first recovery and identity | Deterministic two-device tests; live Drive unauthorized/unverified |
| 50. Conflict resolution UX | Inspected: state/persistence, causal decisions, local-first recovery and identity | Deterministic two-device tests; live Drive unauthorized/unverified |
| 51. Offline behavior and network interruptions | Inspected: state/persistence, causal decisions, local-first recovery and identity | Deterministic two-device tests; live Drive unauthorized/unverified |
| 52. Data deletion, archive, undo and recovery | Inspected: state/persistence, causal decisions, local-first recovery and identity | Deterministic two-device tests; live Drive unauthorized/unverified |
| 53. Backup, import and export UX | Inspected: state/persistence, causal decisions, local-first recovery and identity | Deterministic two-device tests; live Drive unauthorized/unverified |
| 54. Privacy, security and trust | Inspected: state/persistence, causal decisions, local-first recovery and identity | Deterministic two-device tests; live Drive unauthorized/unverified |
| 55. Authentication and account management | Inspected: state/persistence, causal decisions, local-first recovery and identity | Deterministic two-device tests; live Drive unauthorized/unverified |
| 56. Performance and perceived responsiveness | Inspected: bounded materialization/projections and threshold-only edge updates | No release-device performance trace or low-memory claim |
| 57. Crashes, freezes and fault recovery | Inspected: transactional safety, additive migration, date and error boundaries | Automated round trips/failures below; physical timezone/DPI open |
| 58. Updates, migrations and version compatibility | Inspected: transactional safety, additive migration, date and error boundaries | Automated round trips/failures below; physical timezone/DPI open |
| 59. Performance under unusual conditions | Inspected: bounded materialization/projections and threshold-only edge updates | No release-device performance trace or low-memory claim |
| 60. Multi-window and multi-instance behavior | Applicable: native/platform integration inspected | Host/native tests below; physical OS/reader/OEM acceptance open |
| 61. Platform and system integrations | Applicable: native/platform integration inspected | Host/native tests below; physical OS/reader/OEM acceptance open |
| 62. Date, time, numeric and measurement UX | Inspected: transactional safety, additive migration, date and error boundaries | Automated round trips/failures below; physical timezone/DPI open |
| 63. Error prioritization and recovery | Inspected: transactional safety, additive migration, date and error boundaries | Automated round trips/failures below; physical timezone/DPI open |
| 64. Automation and background-operation UX | Applicable: native/platform integration inspected | Host/native tests below; physical OS/reader/OEM acceptance open |
| 65. Ethical and respectful design | Inspected: neutral choices, actual handlers, diff and evidence fidelity | Unobserved checks remain explicit |
| 66. AI-agent-specific UI mistakes | Inspected: neutral choices, actual handlers, diff and evidence fidelity | Unobserved checks remain explicit |
| 67. UI testing and verification failures | Inspected: neutral choices, actual handlers, diff and evidence fidelity | Unobserved checks remain explicit |

## Validation receipt

Prior UI acceptance and beta12 receipts apply only to their recorded boundaries.
New merge/UI assertions require new focused checks. Unchanged encryption,
generation retirement and backup algorithms retain their historical evidence;
they do not establish real Drive or physical platform acceptance for this work.
Commands, source fingerprints and outcomes are recorded below; detailed logs and invocation timestamps remain in the ignored evidence directory.

Times are recorded with UTC offsets in the invocation index and helper receipts.
This work began on 2026-11-05 (UTC+03). Ignored logs/manifests are under
`.buildlog/refinement/`; the first helper receipt is under
`.buildlog/verify/20261105-214258-6885/`. Source is `501e748` plus the named
dirty-source manifest, with native binary identity retained separately.

| Invocation | Result / reason |
| --- | --- |
| `verify.ps1 -Mode Quick -ChangedPaths lib/domain/sync/portable_record_merge.dart,lib/app/sync_controller.dart,lib/features/settings/sync_conflicts_dialog.dart,lib/features/shared/scroll_edge_fade.dart -Tests test/domain/sync/portable_record_merge_test.dart,test/sync_conflicts_dialog_test.dart,test/scroll_edge_fade_test.dart` | Formatting passed; analyzer stopped on four curly-brace infos (two existing). Tests did not run. New merge/UI boundary invalidates previous UI evidence. Helper `result.json` records times/source hashes. |
| Dart MCP `analyze_files`, `dtd listDtdUris/connect` | Initial analysis blocked until root registration; subsequent responses said No errors. CLI compilation later found errors, so MCP responses are insufficient for current-source acceptance. IDE DTD connected with no live app; no personal app hot-reloaded. |
| `flutter analyze --no-pub lib test integration_test test_driver` | `analyze-1.log`: 82 lint/warning findings, including existing baseline debt and new style/unused findings. No error diagnostic at that recorded source. Later source still requires analysis. |
| `dotnet build experiments/widget-shell-probe/widget-shell-probe.csproj -c Release --no-restore` | `native-build-1.log`: pass, zero warnings/errors. New date geometry requires self-test. |
| `tools/dev/native-self-test.ps1 -Executable experiments/widget-shell-probe/bin/Release/net10.0-windows/TodorbitWidget.exe` | `native-self-test-1.log`: failed; old wrapper lost child stderr. Verified disposable child APPDATA/LOCALAPPDATA. |
| Same native binary, redirected child stdout/stderr with disposable `native-diagnostic-2` profile | `native-self-test-2.log`: confirmed 260×230 Tasks content/Quick Add collision after adding a date row. Diagnostic rerun necessary because original wrapper lost details. |
| Same native build command after responsive geometry fix and year-boundary assertion | `native-build-2.log`: pass, zero warnings/errors. Short horizontal widgets use icon navigation while retaining stored customization. |
| Same isolated native self-test after rebuild | `native-self-test-3.log`: pass. Wrapper now retains stdout/stderr. Covers native rendering/layout, existing persistence/revision checks and added calendar year-boundary navigation; does not prove physical shell input/DPI. |
| `flutter test --no-pub --concurrency=1 --reporter=expanded test/refinement_data_test.dart test/domain/sync/portable_record_merge_test.dart test/cloud/sync_batch_codec_test.dart test/sync_apply_repository_test.dart test/sync_conflicts_dialog_test.dart test/scroll_edge_fade_test.dart` | `focused-1.log`, `source-focused-1.json`: 9 merge and 2 scroll cases passed; other files failed compilation on an unescaped SQL JSON path and a const test-fixture constructor. Neither failure is suppressed. |
| Same command omitting the unchanged passing merge and scroll files | `focused-2.log`, `source-focused-2.json`: 60 passed, 6 failed (two recurrence SQL placeholder regressions and four conflict rendering/fixture issues). Necessary after compiler/fixture corrections. New migration, transaction rollback, event relationships, Standard/Private exchange and conflict UI assertions invalidate old relevant receipts. A recurrence INSERT placeholder regression was exposed and needs correction before rerunning its failed assertions. |
| `flutter analyze --no-pub lib test integration_test test_driver` (analysis 2 and 3) | `analyze-2.log`: 117 findings, 10 missing repository-extension import errors. `analyze-3.log`: 109 findings, one missing motion import error. Imports corrected; targeted new curly-brace/context/unused findings corrected. Fresh analysis pending. |
| Native Release build and isolated self-test after deleted-project event-query guard | `native-build-3.log`, `native-self-test-4.log`: pass, zero build warnings/errors. Current native source unchanged since. |
| Focused recurrence/conflict rerun (`--name 'recurrence completion|concurrent recurrence|compact.*large text|changed values lead|short landscape'`) | `focused-3.log`: 5 passed, 1 failed. Corrected recurrence SQL passed; nested disclosure PageStorage collision remained. |
| Conflict disclosure single-case rerun | `conflict-disclosure-4.log`: PageStorage isolation fixed runtime error; assertion tapped before completed layout. Added frame settling; subsequent full conflict file passed. |
| New/existing UI batch attempts 1 and 2 | `ui-batch-1.log`, `ui-batch-2.log`: stopped owned test processes after fake-clock fixture IO stalled. Corrected Close tooltip and real-IO frame pumping; no personal app/profile involved. |
| `flutter test --no-pub --concurrency=1 --reporter=expanded test/refinement_ui_test.dart` | `ui-new-3.log`: all 6 passed (draft resources create/cancel, file integrity, filters, hidden navigation/defaults, motion). |
| `flutter test --no-pub --concurrency=1 --reporter=expanded test/task_editor_schedule_layout_test.dart test/mobile_editors_test.dart test/mobile_workspace_test.dart test/workspace_test.dart test/sync_conflicts_dialog_test.dart test/settings_transfer_test.dart test/task_composition_widget_test.dart` | `ui-existing-4.log`: 57 passed, 9 failed. Schedule/mobile editors, full conflict suite and transfer passed. Old decorative-header/support-location assertions and newly collapsed structure fixtures need updates; root editor scroll failures require diagnosis. |
| Focused corrected failing UI/codec cases (coverage rationale) | Necessary after fixture updates, layout settling and schema mismatch classification; passing unrelated cases reused. |
| Corrected UI/codec invocation (`ui-corrections-5.log`) | 10 passed, 1 failed: recurrence dropdown tap preceded settled scroll layout. The invalid-duration, compact header sizes, Settings/drawer support, create/edit checklist and codec compatibility cases passed. Added frame settling and a hit-testable tap, retaining the actual recurrence creation assertions. |
| `flutter analyze --no-pub lib test integration_test test_driver` | `analyze-4.log`: 27 findings; three removed child-count parameter references exposed by local row cleanup, plus three new infos. Restored computed subtask count, standard shared-widget keys and nullable-element style. Remaining findings belong to unchanged baseline files. |
| Integration serial suite, coverage rationale | Broad shared UI, model, persistence, migration and Sync changes invalidate prior full-suite evidence. Includes all existing protocol/recovery, snapshot, editor and platform host assertions; cannot establish real Drive or physical OS acceptance. |
| Native Release build + isolated self-test (glyph correction) | Source review found placeholder question-mark day arrows in Calendar drawing. Replaced with explicit Unicode escapes; invalidates native-build-3 / self-test-4 painting identity only. Next logs: `native-build-4.log`, `native-self-test-5.log`; no physical input claim. |
| `flutter test --no-pub --concurrency=1 --reporter=expanded` | `integration-1.log`, `source-integration-1.json`: 751 passed, 24 failed, 3 opt-in skipped, 24m39s. Failures: 16 collapsed-field/recurrence/category fixture assumptions; four existing authorization tests asserted native message text rather than typed safe causes; one hard-coded schema 26; one theme-export fixture waited for file existence instead of completed export and raced cleanup; real enlarged Today overflow; category creation not revealing its new row. No failed data-preservation assertion in the exercised Sync/snapshot/recurrence paths. |
| Source corrections after integration-1 | Task header/empty/list share a virtualized scroll owner; successful category creation reveals the row. Remaining inspected vertical forms, lists, navigation and selectors share edge hints; horizontal actual-work timeline stays native. Event windows are labeled, mobile search includes events/assignment names, optional Reports/Contributors and saved-view removal are manageable. Closed filters apply in Inbox too. Snapshot validation rejects inconsistent new relationships. These changes invalidate relevant UI/filter/snapshot evidence, not unchanged protocol/encryption algorithms. |
| Native Computer Use + CUA initialization; `adb devices -l` | Both native UI entry points fail missing kernel assets, os error 3. ADB reports no attached devices. No physical or Android app/launcher pass, no emulator retry or installation. |
| `flutter analyze --no-pub lib test integration_test test_driver` | `analyze-5.log`: zero errors, one new missing-brace info plus 21 existing Sync/test style/unused findings. Applied exact-location brace fixes and removed the unused test import; no changed statements or protocol behavior. |
| Critical correction batch (coverage rationale) | New schema-26 incoming-shape/replay cases, stricter snapshot relationships, event assignment-name filters and Inbox closed statuses require fresh checks. Also checks the corrected schema-22 migration assertion and safe typed authorization assertions. Unchanged existing crypto/causal/retirement crash/retry passes from integration-1 are reused. |
| UI correction batch (coverage rationale) | Inspected shared vertical scroll consumers plus corrected disclosure flows require consolidated widget coverage. New actual recurrence/child UI and draft checklist/goal-link creation journeys close explicit creation-parity coverage gaps. |
| Critical correction batch | `critical-corrections-2.log`, source manifest: 9 passed, 1 failed solely on unordered task titles in the new preservation assertion; changed to unordered equality. Both Standard/Private legacy event/checklist shapes apply and replay unchanged; stricter backup rejection, migration and typed authorization behavior reached the expected assertions. Single failed case rerun below; nine passes reused. |
| Native label correction build/self-test | Selected-day Quick Add now names its actual day; Tasks date heading includes the year outside the current year. New native source invalidates the previous binary identity; `native-build-5.log` and `native-self-test-6.log` record the rerun. |
| `flutter test --no-pub --concurrency=1 --reporter=expanded` with the 67 widget-containing files in `ui-correction-files.json` | `ui-corrections-6.log`: stopped after compilation found the new mobile helper omitted required initialDay. Captured owned test process tree before stopping it; no IDE/personal app process touched. Completely passing independent files are listed in `ui-correction-reused-files.json`; the last in-progress file and all failed/unrun files resume in `ui-correction-remaining-files.json`. Added the event's actual local start day. |
| Single invalid-snapshot preservation rerun | `critical-correction-3.log`: passed. Corrected order-independent assertion; invalid import leaves original checklist/tasks and no scheduled restore. |
| Native Release build / self-test | `native-build-5.log`, `native-self-test-6.log`: passed, zero warnings/errors. Selected-day labels corrected; physical shell/input remains open. |


### Current source/evidence boundary

`integration-1` exercised 778 host cases (751 pass, 24 fail, 3 opt-in skipped).
The named failures remain in the log. Corrected targeted/UI runs supersede only
the affected assertions. Mixed widget/host files may run their companion host
cases in the consolidated file-level UI selection; these are not a claim of a
second entire-protocol audit. No third full Flutter suite is scheduled merely
to refresh evidence. Opt-in profile/native-launch checks use their own disposable
roots. No attached Android device was found; the failed retained AVD is not
booted again without a changed environment.

Widget images establish offscreen layout at their named theme/size only.
The general UI captures use the harness fonts and may show placeholder icon
boxes; the conflict captures load explicit Segoe/MaterialIcons assets. Actual
Windows Debug screenshots/runtime errors and Android launcher observations
are separate evidence. No real Drive, human OS input or performance trace is
inferred from these captures.

| Final focused disclosure/navigation probe (coverage rationale) | Three remaining UI assertions need settled/revealed fields after actual scrolling, without changing their persistence/IME checks. A new route-scroll probe checks that the newly shared task scroll owner does not carry All Tasks' offset into Today and restores its own route history. This new state boundary was not covered by earlier pinned-header tests. |
| Widget correction resume (57 files) | `ui-corrections-7.log`, `source-ui-7.json`: 284 passed, 6 failed, 2 opt-in skipped. New draft checklist/recurrence hierarchy, goal creation links, project-event return context, Today layout and category-creation reveal pass. Residuals: title/notes/color/sidebar lazy scroll sequencing in five existing fixtures; one widget screenshot expected a filename while conflict capture required a directory. Rerun only those cases with completed reveal/settling and the conflict capture variable unset. Previous passing files remain reused. |
| Scope of source reuse | The mechanical braces in unchanged provider/generation/queue/test code change no statements. Existing integration-1 protocol/retirement/replay/crash assertions remain valid for that behavior. New relationship validation and old-record application have separate fresh passes above. |
| Final focused disclosure/navigation probe | `ui-final-focus-8.log`: 4 passed, 3 failed. Color/icon flow, widget Apply/All/Cancel (capture environment corrected), resource-picker cancellation and category deletion/draft protection pass. Remaining event category tap needs a settled reveal; the section helper found both the section title and duplicated inner Details heading. The new scroll probe reproduced All Tasks offset 52px leaking into Today; corrected with route/scope PageStorage identity. Renamed the redundant inner heading Additional fields, targeted the actual section in the helper and retained all data/IME assertions. |
| Visual review | Inspected `conflicts-dark-phone.png` and `conflicts-light-desktop.png`: compact collapsed choices/details are readable; single desktop modal had avoidable blank space. Its height now follows a smaller base scaled with text size. Existing large-text/short-screen bounds remain. `today-empty-large.png` confirms reachable scrolled empty content; harness icon placeholders are not a product icon check. |
| Stabilized final focus (coverage rationale) | Rerun only three failed sequences, both branches of the shared IME fixture, Today after route identity change, and affected single-conflict disclosure/large-text cases. Other passing UI/protocol evidence retained. |
| Stabilized final focus | `final-focus-9.log`: 9 passed, 1 failed at the final offscreen title focus step of the event IME fixture; earlier scroll/focus/draft assertions pass. Finish notes entry before moving to the title. Route-specific scroll identity now passes (All offset formerly leaked 52px into Today); Today and affected compact/large-text/expanded conflict cases pass. |
| Event relationship edge probe (coverage rationale) | Review found a preexisting null-coalescing category override that may ignore an explicit None selection, and legacy override JSON may inherit a project from a different category. Add a synthetic clear/legacy override regression before changing the projection; no personal data. |
| Event edge probe | `event-edge-10.log`: both cases failed. Data case confirms explicit occurrence category None falls back to its series category. Old payload without projectId can inherit a project across categories. Projection now distinguishes absent from explicitly null category and inherits an old project only within the same effective category; raw journals remain unchanged. The IME fixture's final drag target is checked with outer-scroll metrics and a gutter gesture rather than the multiline field viewport. |
| Event edge correction / regression (coverage rationale) | New clear/legacy assertions plus existing event recurrence, project exceptions/splits, both Standard/Private project/checklist and schema-26 application cases, and both IME variants. These are the affected boundaries; unchanged full-suite passes remain reused. |
| Event edge correction / regression | `event-edge-corrected-11.log`: all 12 passed. Explicit category/project clearing, legacy category override, existing recurrence/split and both Standard/Private plus schema-26 incoming exchange pass. Both task/event IME draft/scroll/save sequences pass with the outer-scroll gutter gesture. |
| `flutter test --no-pub --concurrency=1 --reporter=expanded test/refinement_data_test.dart --name 'Today events survive'` | `today-event-window-12.log`: failed, confirming a distant Calendar month empties Today's events. Added a separate bounded Today projection, reusing the Calendar query when today is in range. No unbounded history or recurrence expansion. |
| `flutter test --no-pub --concurrency=1 --reporter=expanded test/refinement_data_test.dart test/calendar_test.dart test/calendar_improvements_test.dart test/event_recurrence_test.dart test/high_use_ui_quality_test.dart test/android_surfaces_test.dart` | `calendar-final-13.log`: 32 passed, one load failure because the last requested filename does not exist. All actual Today/window, Calendar, recurrence, enlarged layout and scroll-history assertions passed. Corrected the Android filename to `android_platform_test.dart` in the next relevant batch; passing other files reused. |
| Native Release build and isolated self-test after category override correction | `native-build-6.log`, `native-self-test-7.log`: passed, zero warnings/errors. Explicit None category no longer inherits the template category color. Later nullable-field changes invalidate the affected projection identity only. |
| `flutter test --no-pub --concurrency=1 --reporter=expanded test/refinement_data_test.dart --name 'event occurrence clearing'` | `event-null-probe-14.log`: failed, confirming optional color clearing also inherited the series value. Extended the same regression for explicit-null color/icon/reminder versus missing legacy keys. Corrected both generated and moved override projections; no journal rewriting. |
| Native Release build with explicit-null styling/reminder regressions | `native-build-7.log`: failed on a missing `JsonSerializer` namespace in the new self-test fixture. Self-test did not run. Qualified the test call; no production behavior changed by that correction. |
| Native Release build and isolated self-test after fixture qualification | `native-build-8.log`, `native-self-test-9.log`: passed, zero warnings/errors. New tests cover explicit category/color/icon clearing and disabled occurrence reminders, alongside existing rendering, lifecycle, stale writes, IPC and persistence checks. |
| `flutter test --no-pub --concurrency=1 --reporter=expanded test/refinement_data_test.dart test/event_recurrence_test.dart test/android_platform_test.dart test/cancelled_event_readability_test.dart test/mobile_workspace_test.dart` | `event-platform-final-15.log`: all 50 passed. New Today window/explicit-null/legacy-key cases plus recurrence, Android reminders, cancelled-event light/dark readability and full mobile workspace/editor/navigation scenarios. Source fingerprint `source-platform-final.json`; unchanged Calendar/high-use assertions from calendar-final-13 reused. |
| `flutter analyze --no-pub` | `analyze-final-6.log`: passed, No issues found. Current tracked/untracked Dart implementation and tests; no production Dart changes after this pass. |
| `dart format --output=none --set-exit-if-changed` on every changed/new Dart file | `format-check-final.log`: 119 files checked, zero changes. New final integration formatting check. |
| `tools/dev/test-profile-journeys.ps1` | `profile-journeys-final.log` and `.buildlog/verify/profile-journeys/20261105-235214-505a8a06/result.json`: all 14 passed. Helper records exact Dart/Flutter snapshot arguments, hashes, fresh child APPDATA/LOCALAPPDATA and result. Covers actual startup preservation, malformed/corrupt/future/legacy data, restore and resource opening/picker adapters. No personal profile. |
| `dart analyze .buildlog/refinement/windows_driver.dart` | `runtime-driver-analyze.log`: no compile errors, three dependency-style infos because the ignored harness reuses transitive vm_service. No dependency added; product analysis remains clean. Harness targets a disposable child and checks its actual environment/resolved DB before any UI action. |
| `tools/build-windows-release.ps1` | `windows-release-final.log`: passed (Flutter Release compile 150.4s), CRT staging/signature and bundle assertions passed. `windows-artifacts-final.json` records main/AOT/companion hashes. Uses the existing Drive-disabled local config; this is not real OAuth/Drive acceptance. No installer or publication performed. |
| `tools/dev/native-self-test.ps1 -Executable build/windows/x64/runner/Release/TodorbitWidget.exe` | `packaged-native-self-test-final.log`: passed in fresh child APPDATA/LOCALAPPDATA. Verifies the bundled single-file companion rather than assuming the standalone build matches it. |
| `flutter --no-version-check --suppress-analytics test --no-pub --concurrency=1 --reporter=expanded test/native_widget_launch_integration_test.dart` with `TODORBIT_NATIVE_SERVICE_EXE` set to the packaged companion | `packaged-native-ipc-final.log`: one passed. `native-ipc-profile.json` records the binary hash and fresh profile under `.buildlog/widget-customization/native-service-profile/`. Actual first launch, repeated restore/Apply reload, configuration preservation and final owned close pass; not physical input/shell acceptance. |
| Android build progress diagnostic: `jcmd 19324 Thread.print` | `android-build-threads.log`: running Gradle DSL configuration, no build deadlock observed. Read-only diagnostic of this build's daemon; no retry, tool install or environment change. |
| Full-suite failure closure review | `integration-failure-closure.json` maps each of the original 24 failed case identifiers to its passing follow-up log (including the renamed reachable Today assertion). This is a log audit, not another full-suite run. Unchanged passing assertions/implementation from integration-1 are reused; changed event/mobile boundaries have the 50-case final pass. |
| Android build progress diagnostic: second `jcmd 19324 Thread.print` | `android-build-threads-2.log`: Gradle waiting for its active Flutter assemble child; subsequent owned-process inspection showed it progressed to Java-only processing. No restart or concurrent Flutter build. |
| `tools/build-android.ps1 -Mode Debug -JavaHome 'C:/Program Files/Android/openjdk/jdk-21.0.8' -AndroidSdk 'D:/AI_Projects/life_manager/.buildlog/android-sdk' -GradleUserHome 'D:/AI_Projects/life_manager/.buildlog/android-gradle-home' -NoPub` | `android-debug-final.log`: failed after 434.2s at `:jni:configureCMakeDebug[arm64-v8a]`, CXX1300: CMake 3.31.6 absent from selected SDK/PATH. Existing Kotlin-plugin future-compatibility and SDK XML warnings also recorded. No application compiler failure reported; no current APK claimed. |
| Existing-tool correction / Android rerun | Confirmed SDK CMake 3.22.1 and existing Visual Studio CMake 3.31.6-msvc6/Ninja. Retry the same helper with those existing CMake/Ninja bins added only to child PATH; no installation, dependency, project build config or source change. Next log: `android-debug-cmake-2.log`. |
| Android build with existing CMake/Ninja on child PATH (same helper/arguments above) | `android-debug-cmake-2.log`: passed in 116.3s. Github Debug APK includes arm64-v8a and x86_64; artifact verifier passed all 7 native libraries' ELF and applicable APK ZIP alignment. `android-artifact-final.json` records SHA-256/size. No install/device runtime performed. Original ignored `android/local.properties` restored byte-for-byte; temporary PATH did not alter project settings. Existing Kotlin-plugin future-compatibility warning remains. |
| Isolated Windows Debug launch: `dart <Flutter tools snapshot> --no-version-check --suppress-analytics run --no-pub -d windows --target lib/driver_main.dart --machine` | Passed. Exact argv/child environment in `windows-live/20261105-235728/launch.json`; machine events/build/app identity in `flutter-machine.log`. APPDATA and LOCALAPPDATA are fresh sibling directories under that root. No production profile or installed app launched. |
| `dart --packages=.dart_tool/package_config.json .buildlog/refinement/windows_driver.dart <own VM HTTP URI> <expected Roaming> <screenshot directory>` | `windows-runtime-driver-1.log`: environment and actual resolved SQLite path verified **before UI actions**. Today/editor/draft URL resource creation and save passed; harness failed on ambiguous Appearance & Themes text shared by navigation and heading. Driver-extension error is recorded, not an app-data or layout failure. |
| Same live driver with `resume-settings` | `windows-runtime-driver-2.log`: passed from the existing Settings route, without recreating the task. Dark theme, filter dialog/Apply and saved task captured. Both attempts reverify the child's actual APPDATA/LOCALAPPDATA/database; receipts and six PNGs are under `windows-live/20261105-235728/screenshots/`. |
| Live screenshot review | Reviewed light common task/editor and draft resource, dark Settings, filters and saved Today task. Actual Segoe UI/Material icons render correctly; primary actions, optional disclosure, resource row and list remain readable in the observed 1264×681 client area. Offscreen harness and physical OS evidence remain distinct. |
| Dart MCP `hot_reload` / `get_runtime_errors` on the isolated VM only | Hot reload passed (0 changed libraries; reassembly completed). Cleared the known ambiguous harness-command error after correcting the harness; subsequent runtime-error query returned No runtime errors found. No app code changed. Closed only this launched app with its observed machine app ID; automatic VM disconnection followed. |
| Read-only live SQLite verification | `windows-live/20261105-235728/database-verified.json`: schema 27, exactly one synthetic Refinement runtime task with its URL resource, and zero foreign-key errors. Database path checked beneath the verified disposable Roaming/TodoPilot root; opened with `mode=ro`. |
| Final source continuity / documentation review | `source-final.json` records implementation commit `f26f6b0`, all changed implementation files and dependency/build configuration hashes. Comparison with `source-platform-final.json` reports **no implementation drift**. Changed relative documentation file links pass. Final `git diff --check` and documentation commit complete this checkpoint; no further code/build rerun is justified by documentation alone. |

## Candidate status and remaining acceptance

Implementation is committed on `feature/sync-ux-refinement`:
`9fd95b5` (data, migration and Sync), `6ca103a` (UI and journeys), and
`f26f6b0` (Windows/Android widget dates). The documentation checkpoint follows
those commits. The three preexisting storage-document changes remain untouched
and excluded. No version/tag, installer publication, release or remote push.

**Ready for isolated private testing. Not approved for release.** Static analysis
and formatting pass; full-suite failures have passing targeted closures; Windows
Release, Android Debug/alignment, native standalone/packaged self-tests, actual
packaged IPC, startup/resource journeys and the live Windows Debug journey pass.
Unchanged protocol/encryption/recovery assertions retain the integration evidence
explained above. This is not a new all-green full-suite run after every correction.

The actual source of the user's unfamiliar Sync records remains **unproven**.
Equivalent deletion-timestamp conflict handling is a confirmed code fix, not proof
that it caused the reported records. No personal or production cloud data was used.

Before release, complete the linked Windows/Android physical checklists: native
shell/menu/input, multiple monitors/DPI, keyboard and Narrator; Android launcher
sizes/date boundaries, multiple widget IDs, IME/Back, TalkBack, OEM/ARM64 and 16 KiB
runtime; Release GUI/upgrade/installer and exact-candidate CI. Real authorized
Google Drive exchange and recovery must exercise independent Windows/Android
profiles, offline concurrent edits/deletes, restore/reconciliation, legacy migration,
Standard and Private keys/recovery, workspace switching and Start New Sync with
safe data. Fake-cloud/adapter passes do not establish this acceptance. The local
Windows Release intentionally follows the existing Drive-disabled config.
