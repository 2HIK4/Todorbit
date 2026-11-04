# UI/UX audit and implementation report template

## Scope and constraints

- Product / repo commit / build version:
- Mode: Build | Audit only | Fix | Polish | Ship review
- Requested scope / excluded surfaces and rationale:
- Platforms / screens / components covered:
- Project instructions read (paths):
- Tooling available and tooling unavailable:
- Existing design system preserved / authorized change:
- Evidence folder / reference:

## Summary

- Fixed and re-tested: `N` issues, with relevant runs and evidence.
- Still open: `N` issues, owner and impact.
- Not tested: `N` relevant scenarios, reason and residual risk.
- Blocked by tooling/environment: `N` relevant scenarios, blocker and next check.
- Shipping recommendation (ship review only): ready for tested scope / conditional / blocked.

## Findings and remediation ledger

For each finding include platform, four-class classification, severity, observed
versus expected experience, reproduction/evidence, confirmed versus suspected
cause, correction, verification result and remaining acceptance. Keep hypotheses
out of confirmed-defect counts. Record the UX Necessity Review outcome and both
inspection perspectives for changed journeys.

| ID | Priority | Screen/component + context | Steps / expected vs actual | Root cause / confidence | Fix or recommended fix | Status / related consumers | Evidence |
|---|---|---|---|---|---|---|---|
| UI-001 | P1 | Route, theme, viewport | Steps and observed divergence | Confirmed or hypothesis | Change or recommendation | Open / Changed pending verification / Fixed and verified; impacted variants | Screenshot/trace/test |

## Coverage matrix

Record all seven coverage dimensions and category applicability. Source-inspected,
automated-tested, runtime-visually-inspected and interactively-verified are
separate evidence columns/rows; mark uninspected and blocked items explicitly.

Use [coverage status definitions](audit-workflow.md#6-close-with-an-auditable-coverage-ledger).
Separate evidence levels and unexecuted required acceptance into distinct rows.

| Surface ID / entry / owner | Viewport/device/platform | Theme/locale/text scale | States/input/check | Applicable? | Execution status / evidence level | Evidence or limitation / next check |
|---|---|---|---|---|---|---|
| Example editor / navigation / shared form | 390 logical px / Android | light / English / 2x | validation / touch / anchor stability | Yes | NOT_TESTED | Planned example only; execute with recorded build |

Reconcile totals against applicable planned rows. List exclusions/N/A reasons and
newly discovered surfaces; do not merge untested variants into a passing screen.

## Test ledger (do not invent entries)

| Test ID | Command or exact manual steps | Scope/platform/commit | Reason and previous run | Outcome | Logs/screenshots |
|---|---|---|---|---|---|
| T01 | `...` | affected page + shared components | changed X; previous run on commit Y | PASS/FAIL/NOT RUN | trace path |

Keep planned checks separate from executed runs. Include failed diagnostics and
each rerun's changed condition, reused receipts/source and why reuse is valid.

## Visual baseline comparison

For each changed screen: before visual, after visual, what changed, which viewport/theme/locale, any unwanted side effects. If visual tooling unavailable, say `NOT CAPTURED` and explain why.

## Accessibility assessment

- Automated scanners and rules used, with exact versions if known:
- Manual keyboard tests:
- Screen reader/device checks performed:
- Contrast/test method:
- Gaps and non-claims: Accessibility scan != formal WCAG compliance certification.

## Outstanding issues / limitations

- Open issue, severity and user impact:
- Missing device/browser/test capability:
- Regressions not tested and why:
- Tooling/environment blockers and narrower evidence obtained:
- User or designer decisions needed:

## Delivery statement

`Within tested scope, [features] were verified on [specific environments]. [N] issues were fixed; [N] remain unresolved; [N] meaningful areas were not testable. We cannot guarantee perfection or zero future bugs.`
