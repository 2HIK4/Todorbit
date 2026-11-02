# UI/UX audit and implementation report template

## Scope and constraints

- Product / repo commit / build version:
- Mode: Build | Audit only | Fix | Polish | Ship review
- Platforms / screens / components covered:
- Project instructions read (paths):
- Tooling available and tooling unavailable:
- Existing design system preserved / authorized change:
- Evidence folder / reference:

## Summary

- Fixed and re-tested: `N` issues, with relevant runs and evidence.
- Still open: `N` issues, owner and impact.
- Not tested: `N` relevant scenarios, reason and residual risk.
- Shipping recommendation: ready for tested scope / conditional / blocked.

## Findings and remediation ledger

| ID | Priority | Screen/component + context | Steps to reproduce | Root cause | Fix or recommended fix | Status | Evidence |
|---|---|---|---|---|---|---|---|
| UI-001 | P1 | Route, theme, viewport | Steps | Cause | Change | Fixed and verified / Open / N/A / Not tested | Screenshot/trace/test |

## Coverage matrix

| Screen/flow | Viewport/device | Theme/locale | States/input | Result | Evidence or limitation |
|---|---|---|---|---|---|
| Example | 390 px iPhone-sized web viewport | light / English | normal, error, keyboard | PASS | snapshot + steps |

## Test ledger (do not invent entries)

| Test ID | Command or exact manual steps | Scope/platform/commit | Reason and previous run | Outcome | Logs/screenshots |
|---|---|---|---|---|---|
| T01 | `...` | affected page + shared components | changed X; previous run on commit Y | PASS/FAIL/NOT RUN | trace path |

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
- User or designer decisions needed:

## Delivery statement

`Within tested scope, [features] were verified on [specific environments]. [N] issues were fixed; [N] remain unresolved; [N] meaningful areas were not testable. We cannot guarantee perfection or zero future bugs.`
