---
name: ultimate-ui-ux
description: "Design, inspect, implement, audit, debug, refactor and polish user experiences. Use for UI, accessibility, interactions, themes, widgets, responsive layouts, and state/service/performance changes affecting visible behavior. Includes usability and complexity review, root-cause diagnosis and evidence-based verification."
---

# Ultimate UI/UX: Design, Diagnose, Fix, Verify

Deliver coherent, operable, accessible and reliable interfaces. A checklist is a
source of hypotheses; passing a compile or screenshot is not proof of correct
behavior. Never claim perfect design, exhaustive defect detection, zero bugs or
accessibility compliance from limited evidence.

Treat four defect classes equally: **visual** (presentation/hierarchy),
**behavioral** (wrong response/state/feedback), **usability** (works but confusing
or costly), and **environmental/edge-case** (fails with different inputs, data,
devices or application states). Automated passes do not establish good UX.

## Start and choose scope

1. Read project instructions, relevant architecture/design tokens and testing
   policy. Preserve data, drafts, preferences, established visual language and
   platform conventions. Use existing shared controls and services.
2. Choose **Build** (new UI), **Audit only** (findings), **Fix** (confirmed defects),
   **Polish** (visual refinement preserving behavior) or **Ship review** (release
   risk and gaps). Audit only does not authorize application edits; ship review
   does not authorize publication. A local fix is not a full app audit.
3. Identify actual surfaces, owners and shared consumers from source/navigation
   and available runtime tools. Record supported platforms and critical journeys.
   Record affected states and the seven coverage dimensions in the audit workflow.
   Read only the reference sections needed below. Reuse this entry point within
   the session unless it changes or necessary context is unavailable.
4. Inspect the rendered failing/baseline state when possible. Verify tooling and
   isolated test data/profile before launching. If unavailable, mark runtime
   coverage **NOT TESTED** or **BLOCKED**, and label code inspection as weaker
   evidence. Do not install tooling or add dependencies just to satisfy a checklist.

## Load by task

| Need | Read |
| --- | --- |
| Every affected screen, major component or journey | Relevant rules in [design standards](references/design-standards.md), including the mandatory UX Necessity Review and implementation/experience inspections |
| Find checks by product area | [67-category coverage inventory](references/problem-coverage.md); choose numbered rows for local work, assess every row's applicability for comprehensive audits |
| A symptom or small UI change | Relevant numbered sections of [issue catalog](references/issue-catalog.md); use its headings/search, not the entire catalog by default |
| Color lost, dependent dates, popup placement, scroll jumping, shared root causes | Relevant investigation in [fix patterns](references/fix-patterns.md) |
| Full audit / ship review | [Audit workflow](references/audit-workflow.md), all 67 coverage categories as applicable, [test matrix](references/test-matrix.md) and [report template](references/report-template.md); detailed symptom catalog only where useful |
| Sync, accounts, offline, conflicts, recovery or OS workers | [Local-first journeys](references/local-first-journeys.md), actual architecture/protocol and current project decisions; never simplify encryption/key/ownership semantics for appearance |
| Select environments, severity, accessibility criteria or evidence | Relevant section of [test matrix](references/test-matrix.md) |
| Flutter on Android/Windows | Relevant sections of [Flutter engineering](references/flutter-engineering.md); [Flutter verification](references/flutter-verification.md) for test selection/recipes |
| Standards or provenance | [Sources](references/sources.md); consult current primary documentation only when the implementation depends on it |

## Diagnose and improve

- Perform two distinct inspections: **Does it work correctly?** and **Should it
  work this way?** The second includes the UX Necessity Review, terminology,
  discoverability, decision/step cost and the user's actual goal. Record justified
  simplification or why the existing complexity is necessary. Never remove a
  capability silently or invent features/defects from the inventory.
- State expected behavior and reproduce with context: platform, viewport, text
  scale, theme, input, data, sequence. Separate an observed defect from a hypothesis
  and a design preference. Prioritize user harm using P0-P3 in the matrix.
- Trace the first incorrect boundary: input -> draft/state -> persistence ->
  projection -> rendering -> feedback. Include lifecycle, ordering and failures;
  do not compensate downstream for corrupted upstream values.
- Find shared implementation and affected callers. Inspect related symptoms and
  consumers even when only one instance was reported. Make confirmed, low-risk
  consistency/usability improvements within scope; track broader discoveries
  rather than silently redesigning flows or changing saved preferences.
- Fix the cause in the correct component, layout rule, semantic token or state
  owner. Avoid arbitrary offsets, clipping, delayed scroll hacks, new parallel
  components and unrelated rewrites. Prevent invalid states only when correction
  is predictable and consistent with domain rules and deliberate user edits.
- For new UI, define the screen's job, primary action and information hierarchy.
  Reuse semantic roles for type, spacing, surfaces, states, focus and motion;
  extend missing tokens deliberately. Prefer readable, simple composition over
  indiscriminate cards, gradients or decoration. Never hide needed content to fit.
- Keep every visible control functional or explicitly unavailable. Protect work
  during navigation, retries and destructive actions; success requires confirmed
  underlying state. Never invent content, progress or metrics.

## Verify and deliver

1. Define an observable correction and affected regression scope before testing.
   Review prior receipts and reuse valid evidence under project policy. Choose
   targeted checks; broaden for shared behavior, data safety or release risk.
2. Reproduce the original sequence, then relevant edge cases and shared consumers.
   Inspect geometry, semantics, interaction and resulting state. Include narrow/
   short sizes, long text/larger text, applicable themes and platform inputs.
   Static checks, widget tests, goldens, runtime and physical OS checks are distinct.
3. Record every executed validation: exact command/action, source/build,
   environment/scope, expected/actual outcome, evidence and new/rerun reason.
   Diagnose failures before retrying; never report a planned test as a pass.
4. Use the report template proportionally (a small fix needs a short receipt).
   Distinguish inspected/pass, inspected/fail, fixed/verified, not tested and
   tooling/environment blocked. Applicability is separate from execution status.
   Include open issues, affected consumers and residual risks.
5. Finish authorized work when scoped fixes and available meaningful checks are
   complete. Report unresolved blockers and unavailable acceptance explicitly;
   do not run indefinite retries or expand into unrelated work for a clean claim.
