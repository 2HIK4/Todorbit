# Prompt 4 — Smart Reschedule UX and reliability (2026-11-17)

## Outcome and source

**PASS for scoped implementation and host verification; live/device/release
acceptance remains pending.** Assigned worktree
`D:/AI_Projects/life_manager_worktrees/feature-todorbit-smart-reschedule`, branch
`feature/todorbit-smart-reschedule`, clean initial HEAD/base
`4d9292cd04455033c81e8ba7884806601f328806`. Branch ancestry was verified before
editing. Only this worktree was changed. No merge, rebase, push, publication,
Stable/version/schema change, new dependency or other worktree modification.

[Final normalized source/assertion/config fingerprints](PROMPT4_SMART_RESCHEDULE_2026_11_17_SOURCE.json)
bind the evidence below. Windows host, Flutter 3.47.7 / Dart 3.13.5, serial tests,
in-memory/disposable databases, no personal profile or account. Commands were
executed on 2026-11-17, UTC+03:00; final evidence recorded around 22:30 local.
The final Git checkpoint is the commit containing this receipt, reported in the
completion message (a commit cannot contain its own hash).

## Root causes and changes

1. Source rows ignored `AppController.taskParents` and recurrence family identity.
   `aa` and child `1` were peers; 15 `OS quiz` occurrences were undifferentiated
   rows. The shared presentation widget now nests children with a connector and
   expansion control. Parent and child selection remains independent by UUID;
   out-of-scope parents are context only. Recurrence families start collapsed,
   with rule type, actual planned range, in-scope occurrence count and selection
   count. Expanded occurrences retain nominal dates and edited/rescheduled flags.
   No hierarchy, generation, rule or identity is rewritten for presentation.
2. Preview rendered one dropdown and repeated unsupported-operation text per
   collision. It now summarizes changes, affected recurring families and issues,
   groups collisions by family, counts distinct other occurrences and exposes
   detailed dates only on expansion. One reviewed Keep decision applies to the
   displayed moving occurrences; Leave unchanged removes those IDs from source
   selection and clears the proposal. A single occurrence's original/proposed
   dates are immediately visible; larger groups expand for details.
3. The old preview checkbox stage could remove an eligibility issue because the
   protected task emitted no change. It could also invalidate collision/dependency
   reasoning by filtering a proposal after review. Source selection is now the
   sole selection stage, and Apply uses the complete reviewed proposal, including
   blocking issues. Swap and other joint operations are never partially filtered.
4. Date/time/day/buffer/split/overlap changes did not consistently invalidate
   previews. All now do, as does returning from availability settings. Generate
   errors remain visible and retryable. Apply always explains its unavailable
   state: no preview, no changes, hard issue, unresolved collisions or warnings
   requiring acknowledgment. Preview and applied states are distinct.
5. Async preview/apply lacked re-entry guards. Both guard before awaiting;
   pointer/focus editing is suspended while pending, Cancel/Back/Close cannot
   dismiss an in-flight Apply, and cancellation of a read-only preview is safe.
   Scoped task IDs are deduplicated before engine calls, preserving order and
   ensuring one proposal/history entry per target. A regression reproduced two
   entries for one duplicated ID before this repair.
6. Scrolling compact warnings exposed a PageStorage type collision: an unkeyed
   expansion control read a stored double offset as a bool. Every new expansion
   control has a distinct stable storage key; source/preview scroll containers
   also retain stable keys. Expansion motion uses the existing reduced-motion
   policy. Rows use standard focusable checkboxes/buttons and semantic theme roles.
7. Existing Smart Reschedule `skipNew` cancels the occurrence without a schedule
   history entry usable by undo. This UI no longer offers skip/cancel or Combine.
   Expanded restrictions explain why; leaving an occurrence unchanged is the
   safe alternative. Series-rule edits remain unavailable here. The repository's
   existing restrictions and other recurrence editing surfaces remain unchanged.
8. An exception after a successful write but failed refresh does not prove
   rollback. Apply error feedback now reports an unconfirmed result, invalidates
   the proposal and requires a fresh preview before retrying.

## Safety and experience scope

The existing SchedulingEngine, AppController and transactional LifeRepository
remain the only scheduling path. No scheduling/domain/persistence engine,
migration, recurrence generator, sync protocol, alarm configuration or native
code was changed. Task moves affect planned dates only; the preview explicitly
states that work sessions stay unchanged. Session operations retain durations
and local start/end display. Actual work and completed tasks are independent.

Production callers share the dialog: Windows Workspace/Calendar and sequence
flows; Android MobileWorkspace menu/per-task action. Inspected states include
selection, collapsed/expanded groups, empty/same-day/no-date results, completed/
locked items, warnings/conflicts, generating/applying/error/cancel and success.
Host tests cover pointer interactions, rapid captured callbacks, scroll-remount,
light/dark 320dp at 2x text and normal desktop geometry. Windows keyboard and
Android Back/IME/TalkBack, physical DPI and real platform behavior are NOT TESTED.
No accessibility certification or measured performance improvement is claimed.

UX necessity review: removed the duplicate preview selection stage and repeated
collision selectors, retained explicit safety acknowledgment, and hid advanced
collision details/restrictions. Group headers are presentation, never implicit
series-wide authorization. Existing compact Fluent tokens and shared action bar,
anchored fields, scroll fade, motion and scheduling functions were reused.

## Executed verification and reuse

Final distinct host tests: **64 PASS / 0 final FAIL / 0 SKIP**, including one
existing compact secondary-surface regression. Do not add overlapping reruns.

| Exact command (from assigned worktree) | Result / reason |
| --- | --- |
| `flutter test --no-pub --concurrency=1 test/prompt4_smart_reschedule_test.dart test/smart_reschedule_widget_test.dart` with `UIUX_CAPTURE_DIR` set to the ignored `.dart_tool/prompt4-captures` directory | Final batch **19 PASS**, 42s. 15 new scenarios plus 4 existing tests; revised UI/call safety invalidated older UI receipts. Real Roboto/Material fonts and Todorbit themes were loaded using the existing capture helper. |
| `flutter test --no-pub --concurrency=1 test/prompt4_smart_reschedule_test.dart --name 'completed occurrences exceptions|repository rejects unsupported Combine'` | **2 PASS**, 5s: strengthened one fixture with nonempty completed-work/alarm records and added one repository Combine rejection. Only this changed assertion and new case rerun; other 19-batch assertions retained. Adds one distinct test. |
| `flutter test --no-pub --concurrency=1 test/prompt4_smart_reschedule_test.dart --name 'aa and 1'` | **1 PASS**, 3s after strengthening the fixture to two children plus a separate hierarchy; no product-source change. Reuses the remaining unchanged focused assertions. |
| `flutter test --no-pub --concurrency=1 test/scheduling_engine_test.dart test/scheduling_repository_test.dart test/series_edit_repository_test.dart test/task_relationships_test.dart test/sync_journal_test.dart` | **43 PASS**, 59s: engine9, scheduling repository8, series10, relationships7, journal9. Exercises current dialog's recurrence/collision/apply/undo/stale/dependency boundary and adjacent capture rollback. |
| `flutter test --no-pub --concurrency=1 test/secondary_surface_quality_test.dart --name 'S13-reschedule'` | **1 PASS**, compact enlarged existing journey; Generate/Cancel remains non-mutating. |
| `flutter analyze --no-pub` | Final full analysis PASS, 0 issues. New shared presentation widgets and preserved restoration callers require final cross-file analysis. |
| `dart format --output=none --set-exit-if-changed lib/features/scheduling/smart_reschedule.dart lib/features/scheduling/schedule_task_list.dart lib/features/scheduling/schedule_preview_details.dart test/prompt4_smart_reschedule_test.dart test/smart_reschedule_widget_test.dart` | PASS. |
| `python tools/dev/check-docs.py` | PASS; links/architecture catalog and skill references. |
| `git diff --check` and final staged diff review | PASS. |

Safety assertions include byte-for-byte database snapshots before/after preview,
error, cancel and rejected Combine; exact selected task/history IDs; preservation
of completed/edited/skipped occurrences, family/series/nominal identities,
nonempty alarms and completed work logs, parent links and sessions; Apply and
undo; no repeated Apply write; same-day and undated states. The adjacent suites
cover persistence restart/migrations, stale atomic rejection, duration/local-day
arithmetic, dependencies and sync-journal transactional ancestry.

Reused separately (not added to executed totals): all **65 fingerprints** in the
[Prompts 2/3 integration manifest](INTEGRATION_P2_P3_2026_11_17_SOURCE.json)
still match. Relevant unchanged persistence/CAS/recurrence/calendar undo-redo/
backup **41-test** and filtered sync compatibility **6-test** receipts remain
valid for those boundaries. AppController, repository/domain source, assertions,
pinned dependencies and Windows SDK environment match. They do not establish
new UI/runtime acceptance. No unchanged full host suite or binary rebuild repeated.

### Diagnostic runs retained, not final passes

- Setup `flutter pub get`: packages resolved without lockfile changes, then plugin
  setup exited1 because Developer Mode/symlink support is unavailable.
- Initial scoped analysis found 3 missing restoration-helper references and 2 lint
  infos; helpers were restored and the next scoped analysis passed. Later scoped
  analysis found 2 brace lint infos, repaired before final analysis.
- Against original HEAD's SmartRescheduleDialog (temporarily substituted and
  restored in `finally`), `flutter test --no-pub --concurrency=1 test/prompt4_smart_reschedule_test.dart --name 'aa and 1|OS quiz 15'`:
  **0 PASS / 2 expected FAIL** reproducing flat hierarchy and ungrouped series.
  The output wrapper's console encoding failed after saving the actual test log;
  source was restored. Ignored `.dart_tool/prompt4_baseline.log` retains output.
- First new-suite run: **5 PASS / 4 FAIL**; test taps needed scroll/layout settling.
  Filtered `--name 'OS quiz 15|input changes|narrow 320'`: **3 PASS / 1 FAIL**;
  the helper additionally needed to restore the lazily unmounted toolbar before
  generating. Both failures were test interaction assumptions, not suppressed.
- One capture run with `--dart-define=PROMPT4_CAPTURE=.dart_tool/prompt4-captures`
  was interrupted after **10 completed passes**, waiting in a bespoke image
  capture callback. Replaced that code with existing `uiux_review_capture.dart`;
  no incomplete run used as completion evidence.
- First complete real-font focused batch: **15 PASS / 1 FAIL**; old compact test
  assumed Generate was initially visible. It now scrolls/settles before tapping.
- `--name 'duplicate scoped'`: **0 PASS / 1 expected FAIL**, proving two proposal
  entries before UUID deduplication.
- Subsequent focused batch: **18 PASS / 1 FAIL**, exposing the actual PageStorage
  double/bool crash during compact warning review. Distinct expansion keys fixed
  it; final 19-test batch above passed, including the original failure sequence.
- Intermediate failed-source snapshots were not retained as reusable receipts;
  only the final fingerprinted source/assertion evidence is reusable.
- DTD discovery found no app; hot reload reported no connected DTD. No hot reload,
  running-app inspection or native launch is claimed. Native launch prerequisite
  is unavailable as recorded above; no personal profile was launched.

Offscreen images were inspected at desktop collision review and narrow light/dark
2x text. They are ignored local artifacts, not actual Windows/Android screenshots:
`.dart_tool/prompt4-captures/{collision-summary,narrow-light,narrow-dark}.png`,
with configuration JSON sidecars. The capture helper records actual theme/size/
font provenance. No generated media or builds are committed.

## Files and skills

Product:
- `lib/features/scheduling/smart_reschedule.dart`
- `lib/features/scheduling/schedule_task_list.dart` (shared hierarchy projection)
- `lib/features/scheduling/schedule_preview_details.dart` (grouped review)

Assertions:
- `test/prompt4_smart_reschedule_test.dart` (16 distinct new tests)
- `test/smart_reschedule_widget_test.dart` (grouped collision/compact journey)

Applied canonical skills: Todorbit Engineering Quality, Ultimate UI/UX and
Todorbit Regression. Reusable lessons were added to existing references:
- `.agents/skills/todorbit-engineering-quality/references/data-safety-and-persistence.md`
- `.agents/skills/ultimate-ui-ux/references/flutter-engineering.md`

Tracking:
- this receipt and `PROMPT4_SMART_RESCHEDULE_2026_11_17_SOURCE.json`
- `docs/TODORBIT_UI_RELIABILITY_PROGRAM.md`
- `docs/PROGRESS.md`
- `docs/TEST_RUN_LEDGER.md`
- `docs/AI_REVIEW_QUEUE.md`
- `docs/DEFERRED_VERIFICATION.md`

Full diff/self-review checked domain ownership, scope, duplicate implementations,
async failure handling, selection identity, recurrence restrictions and layout.
No independent peer sign-off is claimed. Prompt4 is queued for independent
integration review; prior Review History approvals remain unchanged because
self-review is not a new independent approval.

## Remaining acceptance / integration

Ready as a scoped development input for integration alongside Prompt5, subject
to independent integration review and retained platform acceptance. Prompt5/6
were not started and no merge was performed. See the Prompt4 entry in
[Deferred verification](DEFERRED_VERIFICATION.md) for Windows keyboard/DPI/resize,
Android physical Back/IME/touch/TalkBack, process lifecycle and actual alarm
projection/delivery checks. Broad host/platform/release packaging and real-cloud
acceptance remain separate. DST transitions were not exercised on a physical
runtime; scheduling arithmetic was not changed. No release/beta readiness claim.
