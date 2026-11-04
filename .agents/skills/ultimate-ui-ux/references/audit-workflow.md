# Systematic UI audit procedure

Use for a requested comprehensive audit or release review. For a local change,
apply only its affected inventory and regression rows. This workflow grants no
permission to edit an audit-only target or publish a release.

## 1. Establish boundaries and evidence

- Record requested mode, source revision/dirty paths, build identity, supported
  platforms, design system and data/privacy constraints. Check existing receipts
  before running tests; historical artifacts prove only their recorded source.
- List available source, runtime, automation and accessibility tools. For each
  unavailable capability specify what it blocks and what weaker evidence remains.
- Use synthetic fixtures and an isolated profile/device. Verify resolved storage
  paths and child-process environment before launch; environment redirection may
  not isolate credentials, installer registration or a native companion.
- Define important user journeys and invariants: drafts retained, preferences
  retained, correct selected record, confirmed save, safe cancel/retry and no
  silent destructive operation. Capture a reproducible baseline where feasible.

## 2. Inventory reachable surfaces

Reconcile navigation/route declarations, feature map, shared-control callers and
runtime navigation. Keep discovered but inaccessible surfaces in the ledger.
Follow nested menus, conditional actions and permission/first-run entry points;
do not infer coverage from filenames or a screenshot of the home screen.

| Surface family | Discovery probes |
| --- | --- |
| Screens/pages and navigation | routes, tabs, rails, drawers, search, deep links, Back/Forward, queued navigation, first run and locked states |
| Forms/editors | create/edit/read-only, inline editors, dynamic fields, unsaved close, validation, pickers, success/failure |
| Floating surfaces | dialogs, sheets, dropdowns, context menus, nested popups, tooltips, dismiss/focus policy |
| Settings/customization | draft/preview/apply/cancel/reset, light/dark/custom, immediate updates, restart/upgrade persistence |
| Collections/status | lists, tables, calendars, charts, loading/empty/partial/error/success, selection/filter/sort |
| Auxiliary/native UI | desktop widgets/windows/tray, Android launcher widgets, notifications, permission and file-picker UI, app closed/locked |

Assign stable surface IDs, entry paths, owning/shared components, supported
platforms, risk and applicable variants. Split Flutter widgets from Windows HWND
or Android RemoteViews surfaces; they have different render/input/lifecycle paths.
Track excluded or unsupported surfaces with rationale, never as passes.

## 3. Plan representative coverage

Evaluate seven dimensions explicitly: **surface** (including transient/native),
**state** (focus/selection/disabled/empty/pending/success/failure/offline/conflict),
**environment** (OS, bounds, orientation, DPI, text, theme, accessibility),
**interaction** (pointer/keyboard/touch/focus/scroll/navigation), **user journey**
(first/routine/advanced/interrupted/recovered/repeated use), **data scenario**
(empty/typical/large/unusual/old/concurrent), and **quality** (visual, simplicity,
functionality, accessibility, responsiveness, trust, performance).

Use [test matrix](test-matrix.md) to select pairwise combinations and targeted
high-risk intersections. Record why omitted combinations are acceptable. Read
the [67-category inventory](problem-coverage.md) during a full audit; mark applicability
for each category and map relevant checks to surfaces. This is not a requirement
to execute every Cartesian combination or invent nonexistent product states.

Use rows fine-grained enough to distinguish static, rendered, interactive and
physical evidence, for example an editor's IME/Back case separately from its
normal geometry test. A whole screen must not pass because one row did.

## 4. Inspect journeys and transitions

For each selected surface:

Perform both an **implementation inspection** (constraints, controls, data,
state and technical correctness) and an **experience inspection** (user goal,
hierarchy, vocabulary, discoverability and interaction cost). Apply the
[UX Necessity Review](design-standards.md#ux-necessity-review) in the latter.
A functioning screen can still have a confirmed usability problem; support the
claim with a concrete journey, redundant decision or unclear consequence.

1. Reach it by the real entry path; inspect hierarchy, spacing, baselines, wrapping,
   colors/icons and reachable actions at ordinary and stressed geometry.
2. Operate with applicable keyboard, mouse and touch. Verify selected/disabled/
   pressed/focus states and the resulting record/value, not just a callback.
3. Exercise invalid -> corrected -> saved, failure -> retry, cancel and unsaved Back.
   Observe before/during/after frames for layout shifts, flicker and repeated
   messages. Log scroll offset, focused control and visible anchor when relevant.
4. Check long/empty/missing content, slow/pending and rejected writes with existing
   controlled fixtures. Avoid uncontrolled failure injection into personal data.
5. Follow values into every affected presentation; navigate away/back, reopen and
   restart where durability is promised. Check background/resume and external
   widget/deep-link entry without dropping the current draft.
6. Check semantics/assistive input and actual runtime as available. Keep the
   evidence level explicit; a screenshot cannot prove Back or saved state.

## 5. Diagnose, repair and widen deliberately

Record reproduction, expected/actual, severity, evidence and root-cause confidence
before patching. Follow [fix patterns](fix-patterns.md) and framework guidance.
Inspect shared callers and sibling flows for the same cause. Fix confirmed issues
within scope; list unrelated or preference-changing ideas for later review.

After a shared change, cover each materially different consumer variant (e.g.
editable/read-only, anchored/nested modal, desktop/mobile adapter). If new evidence
contradicts the cause, revise the diagnosis before trying another cosmetic patch.

## 6. Close with an auditable coverage ledger

Use these exact execution meanings; **N/A is applicability, not a pass**:

| Status | Required evidence |
| --- | --- |
| INSPECTED_PASS | Named checks actually executed; no issue observed in the recorded scope |
| INSPECTED_FAIL | Reproducible observed issue; link finding and user impact |
| FIXED_VERIFIED | Change plus executed recheck of original failure and affected regressions; unresolved required acceptance stays in separate rows |
| NOT_TESTED | Relevant case not executed; give reason and next check |
| BLOCKED | Required tool, device, environment or access unavailable; name the blocker and narrower evidence |

Keep static findings, open issues, unexecuted cases and fixed/verified issues
separate. Use [report template](report-template.md), reconcile planned vs executed
rows and preserve failed/rerun history. Count only applicable rows with a stated
denominator; counts do not establish defect-detection completeness. Report the
tested scope and remaining gates; avoid universal design/accessibility claims.
